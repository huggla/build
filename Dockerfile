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

ONBUILD RUN mkdir -p /buildfs /imagefs/usr/local/bin \
         && for dir in "$MAKEDIRS"; \
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
         && for exe in "$EXECUTABLES"; \
            do \
               exeDir="$(dirname "$exe")"; \
               if [ "$exeDir" != "/usr/local/bin" ]; \
               then \
                  exeName="$(basename "$exe")"; \
                  cp -a "$exe" "/imagefs/usr/local/bin/"; \
                  cd "/imagefs$exeDir"; \
                  ln -sf "$(relpath "/imagefs$exe" "/imagefs/usr/local/bin/$exeName")" "$exeName"; \
               fi; \
            done
         
