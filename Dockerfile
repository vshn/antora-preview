FROM vshn/antora:2.3.3

RUN addgroup -S preview && adduser -S preview -G preview
RUN mkdir -p /preview && chown -R preview:preview /preview

RUN apk update && apk add unzip
RUN curl --silent --location https://github.com/mikefarah/yq/releases/download/3.3.2/yq_linux_amd64 -o /usr/local/bin/yq
RUN chmod +x /usr/local/bin/yq

RUN curl --silent --location https://github.com/caddyserver/caddy/releases/download/v2.1.1/caddy_2.1.1_linux_amd64.tar.gz -o /antora/caddy.tar.gz
RUN tar -zxvf /antora/caddy.tar.gz
RUN mv /antora/caddy /usr/local/bin/caddy

RUN curl --silent --location https://github.com/appuio/antora-ui-default/releases/download/1.0/ui-bundle.zip -o /preview/bundle.appuio.zip
RUN curl --silent --location https://github.com/projectsyn/antora-ui-default/releases/download/1.3/ui-bundle.zip -o /preview/bundle.syn.zip
RUN curl --silent --location https://github.com/vshn/antora-ui-default/releases/download/1.7/ui-bundle.zip -o /preview/bundle.vshn.zip
RUN curl --silent --location https://gitlab.com/antora/antora-ui-default/-/jobs/artifacts/master/raw/build/ui-bundle.zip?job=bundle-stable -o /preview/bundle.antora.zip

COPY antora-preview.sh /usr/local/bin/
COPY signal-listener.sh /usr/local/bin/

USER preview

COPY playbook.yml /preview/playbook.yml
COPY Caddyfile /preview/Caddyfile

EXPOSE 2020
ENTRYPOINT ["signal-listener.sh"]

