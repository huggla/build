FROM huggla/alpine-official:20181017-edge as image

COPY ./rootfs /tmp/rootfs

RUN chgrp -R 102 /tmp/rootfs \
 && chmod -R o= /tmp/rootfs \
 && chmod u=rx,go= /tmp/rootfs/usr/sbin/relpath \
 && cp -a /tmp/rootfs/* / \
 && rm -rf /tmp/rootfs \
 && apk --no-cache --quiet manifest $APKS | awk -F "  " '{print "/"$2;}' > /apk-tool.filelist \
 && find / -path "/etc/apk/*" -type f >> /apk-tool.filelist

ONBUILD ARG CONTENTSOURCE1
ONBUILD ARG CONTENTDESTINATION1
ONBUILD ARG CONTENTSOURCE2
ONBUILD ARG CONTENTDESTINATION2
ONBUILD ARG DOWNLOADS
ONBUILD ARG ADDREPOS
ONBUILD ARG BUILDDEPS
ONBUILD ARG BUILDDEPS_UNTRUSTED
ONBUILD ARG RUNDEPS
ONBUILD ARG RUNDEPS_UNTRUSTED
ONBUILD ARG MAKEDIRS
ONBUILD ARG MAKEFILES
ONBUILD ARG REMOVEFILES
ONBUILD ARG EXECUTABLES
ONBUILD ARG BUILDCMDS

ONBUILD COPY --from=content1 ${CONTENTSOURCE1:-/} /buildfs${CONTENTDESTINATION1:-/}
ONBUILD COPY --from=content2 ${CONTENTSOURCE2:-/} /buildfs${CONTENTDESTINATION2:-/}
ONBUILD COPY --from=base /onbuild-exclude.filelist.gz /onbuild-exclude.filelist.gz
ONBUILD COPY ./ /tmp/

ONBUILD RUN gunzip /onbuild-exclude.filelist.gz \
         && mkdir -p /imagefs /buildfs/usr/local/bin \
         && while read file; \
            do \
               mkdir -p "/buildfs$(dirname $file)"; \
               cp -a "$file" "/buildfs$file"; \
            done < /apk-tool.filelist \
         && echo $ADDREPOS >> /buildfs/etc/apk/repositories \
         && apk --no-cache --root /buildfs add --initdb \
         && apk --no-cache --root /buildfs --virtual .rundeps add $RUNDEPS \
         && apk --no-cache --root /buildfs --allow-untrusted --virtual .rundeps_untrusted add $RUNDEPS_UNTRUSTED \
         && for dir in $MAKEDIRS; \
            do \
               mkdir -p "$dir" "/buildfs$dir"; \
            done \
         && for file in $MAKEFILES; \
            do \
               mkdir -p "/buildfs$(dirname "$file")"; \
               touch "/buildfs$file"; \
            done \
         && chgrp -R 102 /buildfs /tmp \
         && chmod -R o= /buildfs /tmp \
         && cp -a /tmp/rootfs/* /buildfs/ || true \
         && chgrp 112 /buildfs/etc /buildfs/usr /buildfs/usr/bin /buildfs/usr/lib buildfs/usr/local buildfs/usr/local/bin || true \
         && cd /buildfs \
         && find * -type d -exec mkdir -p /imagefs/{} + \
         && find * ! -type d ! -type c -exec ls -la {} + | awk -F " " '{print $5" "$9}' | sort -u - > /buildfs/onbuild-exclude.filelist \
         && comm -13 /onbuild-exclude.filelist /buildfs/onbuild-exclude.filelist | awk -F " " '{system("cp -a "$2" /imagefs/"$2)}' \
         && cat /onbuild-exclude.filelist /buildfs/onbuild-exclude.filelist | sort -u - | gzip -9 > /imagefs/onbuild-exclude.filelist.gz \
         && chmod go= /imagefs/onbuild-exclude.filelist.gz \
         && echo $ADDREPOS >> /etc/apk/repositories \
         && apk --no-cache add --initdb \
         && cp -a /tmp/buildfs/* /buildfs/ || true \
         && apk --no-cache --virtual .builddeps add $BUILDDEPS \
         && apk --no-cache --allow-untrusted --virtual .builddeps_untrusted add $BUILDDEPS_UNTRUSTED \
         && buildDir="$(mktemp -d -p /buildfs/tmp)" \
         && if [ -n "$DOWNLOADS" ]; \
            then \
               apk --no-cache --virtual .downloaddeps add ssl_client; \
               downloadDir="$(mktemp -d -p /buildfs/tmp)"; \
               cd $downloadDir; \
               for download in $DOWNLOADS; \
               do \
                  wget "$download"; \
               done; \
               tar -xvp -f $downloadDir/* -C $buildDir || true; \
               apk --no-cache --purge del .downloaddeps; \
               rm -rf $downloadDir; \
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
                  if [ "$exeDir" != "/imagefs/usr/local/bin" ]; \
                  then \
                     exeName="$(basename "$exe")"; \
                     cp -a "$exe" "/imagefs/usr/local/bin/"; \
                     cd "$exeDir"; \
                     ln -sf "$(relpath "$exeDir" "/imagefs/usr/local/bin")/$exeName" "$exeName"; \
                  fi; \
               done; \
            fi \
         && rm -rf /imagefs/sys /imagefs/dev /imagefs/proc /tmp/* /imagefs/tmp/* /imagefs/lib/apk /imagefs/etc/apk /imagefs/var/cache/apk/* \
         && for file in $REMOVEFILES; \
            do \
               rm -rf "/imagefs$file"; \
            done \
         && apk --no-cache --purge del .builddeps .builddeps_untrusted
