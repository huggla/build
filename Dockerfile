FROM huggla/apk-tool

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
ONBUILD COPY ./* /tmp/

ONBUILD RUN set -e \
         && mkdir -p /buildfs /imagefs/bin /imagefs/sbin /imagefs/usr/bin /imagefs/usr/sbin /imagefs/tmp /imagefs/usr/local/bin \
         && for dir in $MAKEDIRS; \
            do \
               mkdir -p "$dir" "/imagefs$dir"; \
            done \
         && tar -xvp -f /apk-tool.tar -C / \
         && tar -xvp -f /apk-tool.tar -C /buildfs/ \
         && rm -rf /apk-tool.tar \
         && echo $ADDREPOS >> /buildfs/etc/apk/repositories \
         && apk --no-cache --root /buildfs add --initdb \
         && apk --no-cache --root /buildfs --virtual .rundeps add $RUNDEPS \
         && apk --no-cache --root /buildfs --allow-untrusted --virtual .rundeps_untrusted add $RUNDEPS_UNTRUSTED \
         && cp -a /buildfs/* /imagefs/ \
         && [ -d "/tmp/rootfs" ] && cp -a /tmp/rootfs/* /buildfs/ || /bin/true \
         && [ -d "/tmp/buildfs" ] && cp -a /tmp/buildfs/* /buildfs/ || /bin/true \
         && apk --no-cache --root /buildfs --virtual .builddeps add $BUILDDEPS \
         && apk --no-cache --root /buildfs --allow-untrusted --virtual .builddeps_untrusted add $BUILDDEPS_UNTRUSTED \
         && eval "$RUNCMDS" \
         && [ -d "/tmp/rootfs" ] && cp -a /tmp/rootfs/* /imagefs/ || /bin/true \
         && rm -rf /tmp/* /imagefs/tmp/* /imagefs/lib/apk /imagefs/etc/apk /buildfs $REMOVEFILES \
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
         && chmod go= /imagefs/bin /imagefs/sbin /imagefs/usr/bin /imagefs/usr/sbin
         
