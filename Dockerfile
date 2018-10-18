FROM huggla/apk-tool:20181017-edge as image

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
         && cd /buildfs \
      && echo hej \
         && find * -type d -exec mkdir -p /imagefs/{} + \
      && find * ! -type d ! -type c -exec ls -la {} + \
         && find * ! -type d ! -type c -exec ls -la {} + | awk -F " " '{print $5" "$9}' > /imagefs/onbuild-exclude.filelist \
      && cat /onbuild-exclude.filelist \
      && echo hej2 \
      && cat /imagefs/onbuild-exclude.filelist \
      && echo hej3 \
      && diff -abBdNT -U 0 /onbuild-exclude.filelist /imagefs/onbuild-exclude.filelist \
      && echo hej4
