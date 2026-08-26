FROM quay.io/fedora/python-314:20260826@sha256:41097b98a5f89856a2d1f8c65b099e6760f8972e2951ca77c5f367f6f2aee24f

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

RUN dnf -y install \
        --setopt install_weak_deps=false \
        --nodocs \
        --disablerepo=* \
        --enablerepo=fedora,updates \
        httpd \
        mod_ssl \
        python3-mod_wsgi \
        rpm-build \
    && pip3 install --upgrade --upgrade-strategy eager \
        -r /opt/app-root/src/resultsdb_frontend/requirements.txt \
    && pip3 install --no-deps /opt/app-root/src/resultsdb_frontend \
    && dnf -y remove python3-pip \
    && dnf -y clean all \
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
