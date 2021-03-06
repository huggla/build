FROM huggla/alpine-official as image

COPY ./rootfs /

RUN chmod u+x /usr/sbin/relpath

ONBUILD ARG CONTENTSOURCE1
ONBUILD ARG CONTENTSOURCE1="${CONTENTSOURCE1:-/}"
ONBUILD ARG CONTENTDESTINATION1
ONBUILD ARG CONTENTDESTINATION1="${CONTENTDESTINATION1:-/buildfs/}"
ONBUILD ARG CONTENTSOURCE2
ONBUILD ARG CONTENTSOURCE2="${CONTENTSOURCE2:-/}"
ONBUILD ARG CONTENTDESTINATION2
ONBUILD ARG CONTENTDESTINATION2="${CONTENTDESTINATION2:-/buildfs/}"
ONBUILD ARG CONTENTSOURCE3
ONBUILD ARG CONTENTSOURCE3="${CONTENTSOURCE3:-/}"
ONBUILD ARG CONTENTDESTINATION3
ONBUILD ARG CONTENTDESTINATION3="${CONTENTDESTINATION3:-/buildfs/}"
ONBUILD ARG CLONEGITS
ONBUILD ARG CLONEGITSDIR
ONBUILD ARG DOWNLOADS
ONBUILD ARG DOWNLOADSDIR
ONBUILD ARG ADDREPOS
ONBUILD ARG EXCLUDEAPKS
ONBUILD ARG EXCLUDEDEPS
ONBUILD ARG BUILDDEPS
ONBUILD ARG BUILDDEPS_UNTRUSTED
ONBUILD ARG RUNDEPS
ONBUILD ARG RUNDEPS_UNTRUSTED
ONBUILD ARG INITCMDS
ONBUILD ARG MAKEDIRS
ONBUILD ARG MAKEFILES
ONBUILD ARG GID0WRITABLESRECURSIVE
ONBUILD ARG GID0WRITABLES
ONBUILD ARG REMOVEDIRS
ONBUILD ARG REMOVEFILES
ONBUILD ARG EXECUTABLES
ONBUILD ARG STARTUPEXECUTABLES
ONBUILD ARG EXPOSEFUNCTIONS
ONBUILD ARG BUILDCMDS

ONBUILD RUN mkdir -p /imagefs /buildfs/tmp /buildfs/run /buildfs/var /buildfs/usr/local/bin \
         && chmod 770 /buildfs/tmp \
         && cd /buildfs/var \
         && ln -s ../tmp tmp \
         && ln -s ../run run \
         && cp -a /buildfs/tmp /buildfs/run /buildfs/var /imagefs/

ONBUILD COPY --from=content1 "$CONTENTSOURCE1" "$CONTENTDESTINATION1"
ONBUILD COPY --from=content2 "$CONTENTSOURCE2" "$CONTENTDESTINATION2"
ONBUILD COPY --from=content3 "$CONTENTSOURCE3" "$CONTENTDESTINATION3"
ONBUILD COPY --from=init /environment /environment
ONBUILD COPY ./ /tmp/

ONBUILD RUN chmod go= /environment \
         && tar -x -f /environment/onbuild.tar.gz -C /tmp \
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
                  cd /excludefs; \
                  apk --root /excludefs add --initdb; \
                  ln -s /var/cache/apk/* /excludefs/var/cache/apk/; \
                  if [ -n "$EXCLUDEDEPS" ]; \
                  then \
                     apk --repositories-file /etc/apk/repositories --keys-dir /etc/apk/keys --root /excludefs add $EXCLUDEDEPS; \
                     apk --root /excludefs info -R $EXCLUDEDEPS | grep -v 'depends on:$' | grep -v '^$' | sort -u - | xargs apk --root /excludefs info -L | grep -v 'contains:$' | grep -v '^$' | awk '{system("md5sum \""$0"\"")}' | awk '{first=$1; $1=""; print $0">"first}' | sed 's|^ |/|' | sort -u -o /tmp/onbuild/exclude.filelist /tmp/onbuild/exclude.filelist -; \
                  fi; \
                  if [ -n "$EXCLUDEAPKS" ]; \
                  then \
                     apk --repositories-file /etc/apk/repositories --keys-dir /etc/apk/keys --root /excludefs add $EXCLUDEAPKS; \
                     apk --root /excludefs info -L $EXCLUDEAPKS | grep -v 'contains:$' | grep -v '^$' | awk '{system("md5sum \""$0"\"")}' | awk '{first=$1; $1=""; print $0">"first}' | sed 's|^ |/|' | sort -u -o /tmp/onbuild/exclude.filelist /tmp/onbuild/exclude.filelist -; \
                  fi; \
                  cd /; \
                  rm -rf /excludefs; \
               fi; \
               apk --root /buildfs add --initdb; \
               ln -s /var/cache/apk/* /buildfs/var/cache/apk/; \
               apk --repositories-file /etc/apk/repositories --keys-dir /etc/apk/keys --root /buildfs --virtual .rundeps add $RUNDEPS; \
               apk --repositories-file /etc/apk/repositories --keys-dir /etc/apk/keys --root /buildfs --allow-untrusted --virtual .rundeps_untrusted add $RUNDEPS_UNTRUSTED; \
            fi \
         && if [ -n "$CLONEGITSDIR" ]; \
            then \
               if [ -n "$MAKEDIRS" ]; \
               then \
                  MAKEDIRS="$MAKEDIRS "; \
               fi; \
               MAKEDIRS="$MAKEDIRS$CLONEGITSDIR"; \
               cloneGitsDir="/imagefs$CLONEGITSDIR"; \
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
         && chmod -R o= /imagefs /buildfs \
         && chmod -R g-w,o= "$CONTENTDESTINATION1" "$CONTENTDESTINATION2" \
         && find "$CONTENTDESTINATION1" -type f -perm +010 -exec chmod g-x "{}" + \
         && find "$CONTENTDESTINATION2" -type f -perm +010 -exec chmod g-x "{}" + \
         && chmod u=rx,go= /buildfs/usr/local/bin/* || true \
         && cd /buildfs \
         && if [ -n "$INITCMDS" ]; \
            then \
               eval "$INITCMDS || exit 1"; \
            fi \
         && find * -type d ! -path 'tmp' ! -path 'var' ! -path 'run' ! -path 'var/tmp' ! -path 'var/run' -exec mkdir -m 750 "/imagefs/{}" + \
         && (find * ! -type d ! -type c -type l ! -path 'var/cache/*' ! -path 'tmp/*' -prune -exec echo -n "/{}>" \; -exec readlink "{}" \; && find * ! -type d ! -type c ! -type l ! -path 'var/cache/*' ! -path 'tmp/*' -prune -exec md5sum "{}" \; | awk '{first=$1; $1=""; print $0">"first}' | sed 's|^ |/|') | sort -u - > /tmp/onbuild/exclude.filelist.new \
         && comm -13 /tmp/onbuild/exclude.filelist /tmp/onbuild/exclude.filelist.new | awk -F '>' '{system("cp -a \"."$1"\" \"/imagefs/"$1"\"")}' \
         && chmod 755 /imagefs /imagefs/lib /imagefs/usr /imagefs/usr/lib /imagefs/usr/local /imagefs/usr/local/bin || true \
         && chmod 700 /imagefs/bin /imagefs/sbin /imagefs/usr/bin /imagefs/usr/sbin || true \
         && chmod 750 /imagefs/etc /imagefs/var /imagefs/run /imagefs/var/cache /imagefs/start /imagefs/stop || true \
         && mv /tmp/onbuild/exclude.filelist /tmp/onbuild/exclude.filelist.old \
         && cat /tmp/onbuild/exclude.filelist.old /tmp/onbuild/exclude.filelist.new | sort -u - > /tmp/onbuild/exclude.filelist \
         && apk add --initdb \
         && cp -a /tmp/buildfs/* /buildfs/ || true \
         && apk --virtual .builddeps add $BUILDDEPS \
         && apk --allow-untrusted --virtual .builddeps_untrusted add $BUILDDEPS_UNTRUSTED \
         && buildDir="$(mktemp -d -p /buildfs/tmp)" \
         && if [ -n "$CLONEGITS" ]; \
            then \
               apk add git; \
               if [ -z "$cloneGitsDir" ]; \
               then \
                  cloneGitsDir=$buildDir; \
               fi; \
               cd $cloneGitsDir; \
               for git in "$CLONEGITS"; \
               do \
                  cloneStr="git clone $(eval "echo $(echo $git)")"; \
                  eval "$cloneStr"; \
               done; \
            fi \
         && if [ -n "$DOWNLOADS" ]; \
            then \
               if [ -z "$downloadsDir" ]; \
               then \
                  downloadsDir=$buildDir; \
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
            fi \
         && if [ -n "$BUILDCMDS" ]; \
            then \
               cd $buildDir; \
               eval "$BUILDCMDS || exit 1"; \
            fi \
         && rm -rf /buildfs \
         && if [ -n "$EXECUTABLES" ] || [ -n "$STARTUPEXECUTABLES" ]; \
            then \
               if [ -n "$EXECUTABLES" ] && [ -n "$STARTUPEXECUTABLES" ]; \
               then \
                  EXECUTABLES="$EXECUTABLES $STARTUPEXECUTABLES"; \
               elif [ -z "$EXECUTABLES" ]; \
               then \
                  EXECUTABLES="$STARTUPEXECUTABLES"; \
               fi; \
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
                  if [ "$exeName" == "sudo" ]; \
                  then \
                     chmod ug=rx,o= "/imagefs/usr/local/bin/$exeName"; \
                  else \
                     chmod u=rx,go= "/imagefs/usr/local/bin/$exeName"; \
                  fi \
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
         && rm -rf /imagefs/sys /imagefs/dev /imagefs/proc /imagefs/lib/apk /imagefs/etc/apk \
         && find /imagefs/var/cache ! -type d ! -type c -delete; \
            find /imagefs/tmp ! -type d ! -type c -delete \
         && set -f \
         && for dir in $REMOVEDIRS; \
            do \
               set +f; \
               find "/imagefs$(dirname "$dir")" -name "$(basename "$dir")" -type d -maxdepth 1 -exec rm -rf "{}" +; \
            done \
         && set -f \
         && for file in $REMOVEFILES; \
            do \
               set +f; \
               find "/imagefs$(dirname "$file")" -name "$(basename "$file")" ! -type d ! -type c -maxdepth 1 -exec rm -f "{}" +; \
            done \
         && for exe in $STARTUPEXECUTABLES; \
            do \
               echo "$exe" >> /environment/startupexecutables; \
            done \
         && set -f \
         && for file in $GID0WRITABLES; \
            do \
               set +f; \
               find "/imagefs$(dirname "$file")" -name "$(basename "$file")" -maxdepth 1 -exec chmod g+w "{}" +; \
            done \
         && set -f \
         && for file in $GID0WRITABLESRECURSIVE; \
            do \
               set +f; \
               find "/imagefs$(dirname "$file")" -name "$(basename "$file")" -maxdepth 1 -exec chmod -R g+w "{}" +; \
            done \
         && tar -c -z -f /environment/onbuild.tar.gz -C /tmp onbuild \
         && mv /environment /imagefs/ \
         && apk --purge del .builddeps .builddeps_untrusted
