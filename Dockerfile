FROM huggla/apk-tool:20181005-edge as image

COPY ./rootfs /

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

ONBUILD COPY --from=init / /
ONBUILD COPY --from=init / /imagefs/
ONBUILD COPY ./ /tmp/

ONBUILD RUN chmod +x /usr/sbin/relpath \
         && mkdir -p /buildfs \
         && for dir in $MAKEDIRS; \
            do \
               mkdir -p "$dir" "/imagefs$dir"; \
            done \
         && tar -xvp -f /apk-tool.tar -C / \
         && tar -xvp -f /apk-tool.tar -C /imagefs \
         && rm -f /apk-tool.tar \
         && echo $ADDREPOS >> /etc/apk/repositories \
         && echo $ADDREPOS >> /imagefs/etc/apk/repositories \
         && apk --no-cache add --initdb \
         && apk --no-cache --root /imagefs add --initdb \
         && apk --no-cache --root /imagefs --virtual .rundeps add $RUNDEPS \
         && apk --no-cache --root /imagefs --allow-untrusted --virtual .rundeps_untrusted add $RUNDEPS_UNTRUSTED \
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
         && apk --no-cache --purge del .builddeps .builddeps_untrusted \
         && rm -rf /buildfs \
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
         && chmod o= /imagefs/usr/local/bin/* /tmp /imagefs/bin /imagefs/sbin /imagefs/usr/bin /imagefs/usr/sbin \
         && rm -rf $REMOVEFILES /imagefs/sys /imagefs/dev /imagefs/proc /tmp/* /imagefs/tmp/* /imagefs/lib/apk /imagefs/etc/apk /imagefs/var/cache/apk/*
