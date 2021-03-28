FROM --platform=$BUILDPLATFORM golang:1.16 AS builder-src

ARG VERSION=v7.1.0
ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN git clone https://github.com/oauth2-proxy/oauth2-proxy.git /src/oauth2-proxy

# Copy sources
WORKDIR /src/oauth2-proxy

RUN git checkout ${VERSION}

# Fetch dependencies
RUN GO111MODULE=on go mod download




FROM --platform=$BUILDPLATFORM builder-src AS builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN GOOS=$(echo $TARGETPLATFORM | cut -f1 -d/) && \
    GOARCH=$(echo $TARGETPLATFORM | cut -f2 -d/) && \
    GOARM=$(echo $TARGETPLATFORM | cut -f3 -d/ | sed "s/v//" ) && \
    CGO_ENABLED=0 GOOS=${GOOS} GOARCH=${GOARCH} GOARM=${GOARM} go build -a -installsuffix cgo -ldflags="-X main.VERSION=${VERSION}" -o oauth2-proxy


# Build binary and make sure there is at least an empty key file.
#  This is useful for GCP App Engine custom runtime builds, because
#  you cannot use multiline variables in their app.yaml, so you have to
#  build the key into the container and then tell it where it is
#  by setting OAUTH2_PROXY_JWT_KEY_FILE=/etc/ssl/private/jwt_signing_key.pem
#  in app.yaml instead.
RUN touch jwt_signing_key.pem




FROM gcr.io/distroless/static

COPY --from=builder /src/oauth2-proxy/oauth2-proxy /bin/oauth2-proxy
COPY --from=builder /src/oauth2-proxy/jwt_signing_key.pem /etc/ssl/private/jwt_signing_key.pem

USER 2000:2000

ENTRYPOINT ["/bin/oauth2-proxy"]

