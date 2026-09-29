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
# REV: mswin: Pass INSTALL_STATIC_LIBRARY to RbConfig 2026-09-29T05:50:41Z
ENV RUBY_REVISION=f9ce29e0e6206403dcfabdc2d5ab1ed5a23cbc79
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
