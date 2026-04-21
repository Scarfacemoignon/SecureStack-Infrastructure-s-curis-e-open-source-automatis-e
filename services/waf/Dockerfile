FROM owasp/modsecurity-crs:nginx-alpine

# L'image officielle OWASP intègre déjà :
# - Nginx
# - ModSecurity v3
# - OWASP Core Rule Set (CRS) dernière version

COPY nginx-waf.conf /etc/nginx/templates/conf.d/default.conf.template
COPY modsecurity-override.conf /etc/modsecurity.d/setup.conf

EXPOSE 80 443

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD wget -qO- http://localhost/health || exit 1
