FROM huggla/apk-tool:20181017-edge as apk-tool
FROM huggla/busybox:20181017-edge as image

COPY ./rootfs /
COPY --from=apk-tool /apk-tool /

RUN rm -f /onbuild-exclude.filelist* \
 && chmod +x /usr/sbin/relpath

ONBUILD ARG IMAGE
ONBUILD ARG DOWNLOADS
ONBUILD ARG ADDREPOS
ONBUILD ARG BUILDDEPS
ONBUILD ARG BUILDDEPS_UNTRUSTED
ONBUILD ARG RUNDEPS
ONBUILD ARG RUNDEPS_UNTRUSTED
ONBUILD ARG MAKEDIRS
ONBUILD ARG REMOVEFILES
ONBUILD ARG EXECUTABLES
ONBUILD ARG BUILDCMDS

#ONBUILD COPY --from=init / /imagefs
ONBUILD COPY --from=init /onbuild-exclude.filelist.gz /onbuild-exclude.filelist.gz
ONBUILD COPY ./ /tmp/

ONBUILD RUN gunzip /onbuild-exclude.filelist.gz \
         && mkdir /imagefs \
         && for dir in $MAKEDIRS; \
            do \
               mkdir -p "$dir" "/imagefs$dir"; \
            done \
         && while read file; \
            do \
               mkdir -p "/buildfs$(dirname $file)"; \
               cp -a "$file" "/buildfs$file"; \
            done < /apk-tool.filelist \
         && echo $ADDREPOS >> /buildfs/etc/apk/repositories \
         && apk --no-cache --root /buildfs add --initdb \
         && apk --no-cache --root /buildfs --virtual .rundeps add $RUNDEPS \
         && apk --no-cache --root /buildfs --allow-untrusted --virtual .rundeps_untrusted add $RUNDEPS_UNTRUSTED \
         && cd /buildfs \
         && find * -type d -exec mkdir -p /imagefs/{} + \
         && find * ! -type d ! -type c -exec ls -la {} + | awk -F " " '{print $5" "$9}' | sort -u - > /buildfs/onbuild-exclude.filelist \
         && comm -13 /onbuild-exclude.filelist /buildfs/onbuild-exclude.filelist | awk -F " " '{system("cp -a "$2" /imagefs/"$2)}' \
         && cat /onbuild-exclude.filelist /buildfs/onbuild-exclude.filelist | sort -u - > /imagefs/onbuild-exclude.filelist \
         && gzip -f /imagefs/onbuild-exclude.filelist \
         && echo $ADDREPOS >> /etc/apk/repositories \
         && apk --no-cache add --initdb \
         && cp -a /tmp/rootfs/* /buildfs/ || /bin/true \
         && cp -a /tmp/buildfs/* /buildfs/ || /bin/true \
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
               tar -xvp -f $downloadDir/* -C $buildDir || /bin/true; \
               apk --no-cache --purge del .downloaddeps; \
               rm -rf $downloadDir; \
            fi \
         && cp -a /tmp/rootfs/* /imagefs/ || /bin/true \
         && if [ -n "$BUILDCMDS" ]; \
            then \
               cd $buildDir; \
               eval "$BUILDCMDS || exit 1"; \
            fi \
         && rm -rf /buildfs \
         && if [ -n "$EXECUTABLES" ]; \
            then \
               mkdir -p /imagefs/usr/local/bin; \
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
         && chmod o= /tmp /imagefs/bin /imagefs/sbin /imagefs/usr/bin /imagefs/usr/sbin /imagefs/usr/local/bin/* || /bin/true \
         && rm -rf $REMOVEFILES /imagefs/sys /imagefs/dev /imagefs/proc /tmp/* /imagefs/tmp/* /imagefs/lib/apk /imagefs/etc/apk /imagefs/var/cache/apk/* \
         && apk --no-cache --purge del .builddeps .builddeps_untrusted
