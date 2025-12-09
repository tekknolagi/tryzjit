FROM ubuntu:24.04 as builder
RUN apt update -y && apt install -y \
    clang \
    git \
    autoconf \
    rustup \
    ruby \
    libatomic1 \
    make && \
    rm -rf /var/lib/apt/lists/*
RUN rustup default 1.85

# Note that this doesn't compile the psych, zlib, or openssl extensions
FROM builder as build
WORKDIR /app
# [ruby/prism] Fix wrong error message for lower percent i arrays
ENV RUBY_REVISION=d5c7cf0a1a1d2a72421b9a166e19442f89b99868
RUN git init ruby && \
    cd ruby && \
    git remote add origin https://github.com/ruby/ruby.git && \
    git fetch --depth=1 origin "$RUBY_REVISION" && \
    git reset --hard FETCH_HEAD
WORKDIR /app/ruby
RUN ./autogen.sh
RUN ./configure --enable-zjit=dev --disable-yjit --prefix=/usr/local --disable-install-doc
RUN make -sj $(nproc)
RUN make install

FROM ubuntu:24.04 as server_builder
RUN apt update -y && apt install -y libatomic1 && \
    rm -rf /var/lib/apt/lists/*

FROM server_builder as explorer
COPY --from=build /usr/local /usr/local
COPY static/ /app/static
COPY server.rb /app/server.rb
WORKDIR /app
EXPOSE 8081
ENTRYPOINT ["ruby", "server.rb"]
