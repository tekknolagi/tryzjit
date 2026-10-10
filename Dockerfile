FROM ubuntu:24.04 as builder
RUN apt -y update
RUN apt install -y \
    clang \
    git \
    autoconf \
    rustup \
    ruby \
    libatomic1 \
    make
RUN adduser --disabled-password user
USER user
RUN rustup default 1.85

FROM builder as build
WORKDIR /app
# REV: [ruby/date] Deprecate lenient RFC 3339 date time separators 2026-10-09T22:45:03Z
ENV RUBY_REVISION=a9d3eadfc8d1bac29f014b52e83bcb908a595c73
RUN git init ruby
WORKDIR /app/ruby
RUN git remote add origin https://github.com/ruby/ruby.git
RUN git fetch --depth=1 origin "$RUBY_REVISION"
RUN git reset --hard FETCH_HEAD
RUN ./autogen.sh
RUN ./configure --prefix=/usr/local --enable-zjit=dev --disable-yjit --disable-install-doc
RUN make -sj $(nproc)
USER root
RUN make install
USER user

FROM ubuntu:24.04 as server_builder

FROM server_builder as explorer
COPY --from=build /usr/local /usr/local
COPY website/ /app/website
WORKDIR /app
EXPOSE 8081
ENTRYPOINT ["ruby", "website/server.rb"]
