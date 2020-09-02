FROM vshn/antora:2.3.3

RUN apk update && apk add unzip
RUN curl --silent --location https://github.com/mikefarah/yq/releases/download/3.3.2/yq_linux_amd64 -o /usr/local/bin/yq
RUN chmod +x /usr/local/bin/yq

RUN curl --silent --location https://github.com/caddyserver/caddy/releases/download/v2.1.1/caddy_2.1.1_linux_amd64.tar.gz -o /antora/caddy.tar.gz
RUN tar -zxvf /antora/caddy.tar.gz
RUN mv /antora/caddy /usr/local/bin/caddy

RUN curl --silent --location https://github.com/appuio/antora-ui-default/releases/download/1.0/ui-bundle.zip -o /bundle.appuio.zip
RUN curl --silent --location https://github.com/projectsyn/antora-ui-default/releases/download/1.3/ui-bundle.zip -o /bundle.syn.zip
RUN curl --silent --location https://github.com/vshn/antora-ui-default/releases/download/1.7/ui-bundle.zip -o /bundle.vshn.zip

COPY antora-preview.sh /usr/local/bin/
COPY signal-listener.sh /usr/local/bin/
COPY playbook.yml /playbook.yml
COPY Caddyfile /Caddyfile

EXPOSE 2020
ENTRYPOINT ["signal-listener.sh"]

