FROM huggla/apk-tool as image

COPY ./rootfs /

ONBUILD ARG ADDREPOS
ONBUILD ARG BUILDDEPS
ONBUILD ARG BUILDDEPS_UNTRUSTED
ONBUILD ARG RUNDEPS
ONBUILD ARG RUNDEPS_UNTRUSTED
ONBUILD ARG MAKEDIRS
ONBUILD ARG REMOVEFILES
ONBUILD ARG EXECUTABLES
ONBUILD ARG BUILDCMDS

ONBUILD COPY --from=init / /
ONBUILD COPY --from=init / /imagefs/
ONBUILD COPY ./ /tmp/

ONBUILD RUN mkdir -p /buildfs \
         && for dir in $MAKEDIRS; \
            do \
               mkdir -p "$dir" "/imagefs$dir"; \
            done \
         && tar -xvp -f /apk-tool.tar -C / \
         && rm -f /apk-tool.tar \
         && while read file; \
            do \
               mkdir -p "/buildfs$(dirname $file)"; \
               ln -sf "$file" "/buildfs$file"; \
            done < /apk-tool.filelist \
         && echo $ADDREPOS >> /buildfs/etc/apk/repositories \
         && apk --no-cache --root /buildfs add --initdb \
         && apk --no-cache --root /buildfs --virtual .rundeps add $RUNDEPS \
         && apk --no-cache --root /buildfs --allow-untrusted --virtual .rundeps_untrusted add $RUNDEPS_UNTRUSTED \
         && cp -a /buildfs/* /imagefs/ \
         && [ -d "/tmp/rootfs" ] && cp -a /tmp/rootfs/* /buildfs/ || /bin/true \
         && [ -d "/tmp/buildfs" ] && cp -a /tmp/buildfs/* /buildfs/ || /bin/true \
         && apk --no-cache --root /buildfs --virtual .builddeps add $BUILDDEPS \
         && apk --no-cache --root /buildfs --allow-untrusted --virtual .builddeps_untrusted add $BUILDDEPS_UNTRUSTED \
         && eval "$BUILDCMDS" \
         && [ -d "/tmp/rootfs" ] && cp -a /tmp/rootfs/* /imagefs/ || /bin/true \
         && chmod +x /usr/sbin/relpath \
         && for exe in $EXECUTABLES; \
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
            done \
         && chmod o= /imagefs/usr/local/bin/* /tmp \
         && chmod go= /imagefs/bin /imagefs/sbin /imagefs/usr/bin /imagefs/usr/sbin \
         && while read file; \
            do \
               if [ ! -e "/imagefs$file" ]; \
               then \
                  rm -rf "/imagefs$file"; \
               fi; \
            done < /apk-tool.filelist \
         && rm -rf $REMOVEFILES /imagefs/sys /imagefs/dev /imagefs/proc /tmp/* /imagefs/tmp/* /imagefs/lib/apk /imagefs/etc/apk /imagefs/var/cache/apk/* /buildfs
