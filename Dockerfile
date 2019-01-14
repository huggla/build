FROM huggla/alpine-official as image

COPY ./rootfs /

RUN chmod u+x /usr/sbin/relpath

ONBUILD ARG CONTENTSOURCE1
ONBUILD ARG CONTENTDESTINATION1
ONBUILD ARG CONTENTSOURCE2
ONBUILD ARG CONTENTDESTINATION2
ONBUILD ARG DOWNLOADS
ONBUILD ARG DOWNLOADSDIR
ONBUILD ARG ADDREPOS
ONBUILD ARG EXCLUDEAPKS
ONBUILD ARG EXCLUDEDEPS
ONBUILD ARG BUILDDEPS
ONBUILD ARG BUILDDEPS_UNTRUSTED
ONBUILD ARG RUNDEPS
ONBUILD ARG RUNDEPS_UNTRUSTED
ONBUILD ARG MAKEDIRS
ONBUILD ARG MAKEFILES
ONBUILD ARG REMOVEFILES
ONBUILD ARG EXECUTABLES
ONBUILD ARG EXPOSEFUNCTIONS
ONBUILD ARG BUILDCMDS

ONBUILD COPY --from=content1 ${CONTENTSOURCE1:-/} ${CONTENTDESTINATION1:-/buildfs/}
ONBUILD COPY --from=content2 ${CONTENTSOURCE2:-/} ${CONTENTDESTINATION2:-/buildfs/}
ONBUILD COPY --from=init /onbuild-exclude.filelist.gz /onbuild-exclude.filelist.gz
ONBUILD COPY ./ /tmp/

ONBUILD RUN gunzip /onbuild-exclude.filelist.gz \
         && mkdir -p /imagefs /buildfs/usr/local/bin \
         && if [ -n "$ADDREPOS" ]; \
            then \
               for repo in $ADDREPOS; \
               do \
                  echo $repo >> /etc/apk/repositories; \
               done; \
            fi \
         && apk update \
         && apk upgrade \
         && if [ -n "$RUNDEPS" ]; \
            then \
               if [ -n "$EXCLUDEDEPS" ] || [ -n "$EXCLUDEAPKS" ]; \
               then \
                  mkdir /excludefs; \
                  apk --root /excludefs add --initdb; \
                  ln -s /var/cache/apk/* /excludefs/var/cache/apk/; \
                  if [ -n "$EXCLUDEDEPS" ]; \
                  then \
                     apk --repositories-file /etc/apk/repositories --keys-dir /etc/apk/keys --root /excludefs add $EXCLUDEDEPS; \
                     apk --root /excludefs info -R $EXCLUDEDEPS | grep -v 'depends on:$' | grep -v '^$' | sort -u - | xargs apk info -L | grep -v 'contains:$' | grep -v '^$' | awk '{system("md5sum /"$1)}' | sort -u -o /onbuild-exclude.filelist /onbuild-exclude.filelist -; \
                  fi; \
                  if [ -n "$EXCLUDEAPKS" ]; \
                  then \
                     apk --repositories-file /etc/apk/repositories --keys-dir /etc/apk/keys --root /excludefs add $EXCLUDEAPKS; \
                     apk --root /excludefs info -L $EXCLUDEAPKS | grep -v 'contains:$' | grep -v '^$' | awk '{system("md5sum /"$1)}' | sort -u -o /onbuild-exclude.filelist /onbuild-exclude.filelist -; \
                  fi; \
                  rm -rf /excludefs; \
               fi; \
               apk --root /buildfs add --initdb; \
               ln -s /var/cache/apk/* /buildfs/var/cache/apk/; \
               apk --repositories-file /etc/apk/repositories --keys-dir /etc/apk/keys --root /buildfs --virtual .rundeps add $RUNDEPS; \
               apk --repositories-file /etc/apk/repositories --keys-dir /etc/apk/keys --root /buildfs --allow-untrusted --virtual .rundeps_untrusted add $RUNDEPS_UNTRUSTED; \
            fi \
         && if [ -n "$DOWNLOADSDIR" ]; \
            then \
               if [ -n "$MAKEDIRS" ]; \
               then \
                  MAKEDIRS="$MAKEDIRS "; \
               fi; \
               MAKEDIRS=$MAKEDIRS$DOWNLOADSDIR; \
               downloadsDir="/imagefs$DOWNLOADSDIR"; \
            fi \
         && for dir in $MAKEDIRS; \
            do \
               mkdir -p "$dir" "/buildfs$dir"; \
            done \
         && for file in $MAKEFILES; \
            do \
               mkdir -p "/buildfs$(dirname "$file")"; \
               touch "/buildfs$file"; \
            done \
         && cp -a /tmp/rootfs/* /buildfs/ || true \
         && chmod ug=rx,o= /buildfs/usr/local/bin/* || true \
         && cd /buildfs \
         && find * -type d -exec mkdir -p /imagefs/{} + \
         && find * ! -type d ! -type c -exec md5sum {} + | sort -u - > /onbuild-exclude.filelist.tmp \
         && comm -13 /onbuild-exclude.filelist /onbuild-exclude.filelist.tmp | awk -F " " '{system("cp -a "$2" /imagefs/"$2)}' \
         && chmod 755 /imagefs /imagefs/lib /imagefs/usr /imagefs/usr/lib /imagefs/usr/local /imagefs/usr/local/bin || true \
         && chmod 700 /imagefs/bin /imagefs/sbin /imagefs/usr/bin /imagefs/usr/sbin || true \
         && chmod 750 /imagefs/etc /imagefs/var /imagefs/run /imagefs/var/cache /imagefs/start /imagefs/stop || true \
         && chmod 770 /imagefs/tmp || true \
         && cat /onbuild-exclude.filelist /onbuild-exclude.filelist.tmp | sort -u - | gzip -9 > /imagefs/onbuild-exclude.filelist.gz \
         && chmod go= /imagefs/onbuild-exclude.filelist.gz \
         && apk add --initdb \
         && cp -a /tmp/buildfs/* /buildfs/ || true \
         && apk --virtual .builddeps add $BUILDDEPS \
         && apk --allow-untrusted --virtual .builddeps_untrusted add $BUILDDEPS_UNTRUSTED \
         && buildDir="$(mktemp -d -p /buildfs/tmp)" \
         && if [ -n "$DOWNLOADS" ]; \
            then \
               apk --virtual .downloaddeps add wget ca-certificates; \
               if [ -z "$downloadsDir" ]; \
               then \
                  downloadsDir="$(mktemp -d -p /buildfs/tmp)"; \
               fi; \
               cd $downloadsDir; \
               for download in $DOWNLOADS; \
               do \
                  wget "$download"; \
               done; \
               if [ -z "$DOWNLOADSDIR" ]; \
               then \
                  tar -xvp -f $downloadsDir/*.tar* -C $buildDir || true; \
               fi; \
               apk --purge del .downloaddeps; \
            fi \
         && if [ -n "$BUILDCMDS" ]; \
            then \
               cd $buildDir; \
               eval "$BUILDCMDS || exit 1"; \
            fi \
         && rm -rf /buildfs \
         && if [ -n "$EXECUTABLES" ]; \
            then \
               for exe in $EXECUTABLES; \
               do \
                  exe="/imagefs$exe"; \
                  exeDir="$(dirname "$exe")"; \
                  exeName="$(basename "$exe")"; \
                  if [ "$exeDir" != "/imagefs/usr/local/bin" ]; \
                  then \
                     cp -a "$exe" "/imagefs/usr/local/bin/"; \
                     cd "$exeDir"; \
                     ln -sf "$(relpath "$exeDir" "/imagefs/usr/local/bin")/$exeName" "$exeName"; \
                  fi; \
                  chmod ug=rx,o= "/imagefs/usr/local/bin/$exeName"; \
               done; \
            fi \
         && if [ -n "$EXPOSEFUNCTIONS" ]; \
            then \
               mkdir -p /imagefs/usr/local/bin/functions; \
               cd /imagefs/usr/local/bin; \
               ln -s ../../../start/includeFunctions ./; \
               cd /imagefs/usr/local/bin/functions; \
               for func in $EXPOSEFUNCTIONS; \
               do \
                  ln -s ../../../../start/functions/$func ./; \
               done; \
            fi \
         && rm -rf /imagefs/sys /imagefs/dev /imagefs/proc /tmp/* /imagefs/tmp/* /imagefs/lib/apk /imagefs/etc/apk /imagefs/var/cache/apk/* \
         && for file in $REMOVEFILES; \
            do \
               rm -rf "/imagefs$file"; \
            done \
         && apk --purge del .builddeps .builddeps_untrusted
