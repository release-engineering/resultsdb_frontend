# This will produce an image to be used in Openshift
# Build should be triggered from repo root like:
# docker build -f Dockerfile --tag <IMAGE_TAG>

FROM registry.fedoraproject.org/fedora-minimal:38

ARG GITHUB_SHA
LABEL \
    name="ResultsDB_frontend application" \
    description="ResultsDB_frontend is a simple application that allows browsing the data stored inside ResultsDB." \
    maintainer="Red Hat, Inc." \
    license="GPLv2+" \
    url="https://github.com/release-engineering/resultsdb_frontend" \
    vcs-type="git" \
    vcs-ref=$GITHUB_SHA \
    io.k8s.display-name="ResultsDB_frontend"

USER root

ARG DEFAULT_LOG_LEVEL=info

ENV \
    PIP_DEFAULT_TIMEOUT=100 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random \
    PYTHONUNBUFFERED=1 \
    LOG_LEVEL=$DEFAULT_LOG_LEVEL \
    RESULTSDB_FRONTEND_CONFIG=/etc/resultsdb_frontend/settings.py

COPY . /opt/app-root/src/resultsdb_frontend/

RUN microdnf -y install \
        findutils \
        httpd \
        mod_ssl \
        python3-mod_wsgi \
        python3-pip \
        python3-cachelib \
        python3-flask \
        python3-iso8601 \
        python3-resultsdb_api \
        rpm-build \
    && microdnf -y clean all \
    && pip3 install /opt/app-root/src/resultsdb_frontend \
    && install -d /usr/share/resultsdb_frontend/conf \
    && install -p -m 0644 \
        /opt/app-root/src/resultsdb_frontend/conf/resultsdb_frontend.conf \
        /usr/share/resultsdb_frontend/conf/ \
    && install -p -m 0644 \
        /opt/app-root/src/resultsdb_frontend/conf/resultsdb_frontend.wsgi \
        /usr/share/resultsdb_frontend/ \
    && install -d /etc/resultsdb_frontend \
    && install -p -m 0644 \
        /opt/app-root/src/resultsdb_frontend/conf/resultsdb_frontend.conf \
        /etc/httpd/conf.d/ \
    # fix apache config for container use
    && sed -i 's#^WSGISocketPrefix .*#WSGISocketPrefix /tmp/wsgi#' \
        /opt/app-root/src/resultsdb_frontend/conf/resultsdb_frontend.conf

EXPOSE 5002

CMD ["mod_wsgi-express-3", "start-server", "/usr/share/resultsdb_frontend/resultsdb_frontend.wsgi", \
    "--user", "apache", "--group", "apache", \
    "--port", "5002", "--threads", "5", \
    "--include-file", "/etc/httpd/conf.d/resultsdb_frontend.conf", \
    "--log-level", "${LOG_LEVEL}", \
    "--log-to-terminal", \
    "--access-log", \
    "--startup-log" \
]
USER 1001:0
