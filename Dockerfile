FROM ubuntu:24.04 as builder
RUN apt -y update
RUN apt install -y \
    clang \
    git \
    autoconf \
    rustup \
    ruby \
    make
RUN adduser --disabled-password user
USER user
RUN rustup default 1.85

FROM builder as build
WORKDIR /app
RUN git clone --depth=1 https://github.com/ruby/ruby.git
WORKDIR /app/ruby
RUN ./autogen.sh
RUN ./configure --enable-zjit=dev --disable-yjit
RUN make -sj $(nproc)

FROM build as explorer
COPY --from=build /app/ruby/ruby /usr/local/bin/ruby
COPY website/ /app/website
WORKDIR /app/website
ENTRYPOINT python3 gen.py explorer --runtime /usr/local/bin/ruby --ipv6
