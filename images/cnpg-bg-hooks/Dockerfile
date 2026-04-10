FROM alpine:3.20

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG KUBECTL_VERSION=1.31.4
ARG HELM_VERSION=3.16.4

# hadolint ignore=DL3018
RUN apk add --no-cache bash jq curl \
  && curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  -o /usr/local/bin/kubectl \
  && chmod +x /usr/local/bin/kubectl \
  && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
  | tar xz -C /usr/local/bin --strip-components=1 linux-amd64/helm \
  && apk del curl

COPY images/cnpg-bg-hooks/scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Hooks run as short-lived Kubernetes Jobs; no HTTP endpoint to health-check.
HEALTHCHECK NONE

USER 65534:65534
ENTRYPOINT ["/scripts/entrypoint.sh"]
