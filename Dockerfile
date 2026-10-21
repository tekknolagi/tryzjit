FROM ubuntu:24.04 as builder
RUN apt -y update
RUN apt install -y \
    clang \
    git \
    autoconf \
    rustup \
    ruby \
    libatomic1 \
    libffi-dev \
    libssl-dev \
    libyaml-dev \
    patch \
    pkg-config \
    zlib1g-dev \
    make
RUN adduser --disabled-password user
USER user
RUN rustup default 1.85

FROM builder as build
WORKDIR /app
# REV: Keep capture group indices in long 2026-10-21T04:37:54Z
ENV RUBY_REVISION=6a81db9d5ff8e8db2a40a33885ff290c6425cc22
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

# RAILS REV: Keep route redirects from a string template on the request host (#59218) 2026-10-21T16:53:50Z
ENV RAILS_REVISION=36e0f96b9d7a022755a53a2a9fb7a67ad4e3669e
COPY rails/Gemfile rails/setup.sh /app/rails/
RUN /app/rails/setup.sh
USER user

FROM ubuntu:24.04 as server_builder
RUN apt -y update && apt install -y --no-install-recommends \
    libffi8 \
    libssl3t64 \
    libyaml-0-2 \
    zlib1g \
  && rm -rf /var/lib/apt/lists/*

FROM server_builder as explorer
COPY --from=build /usr/local /usr/local
COPY --from=build /app/rails /app/rails
COPY website/ /app/website
WORKDIR /app
EXPOSE 8081
ENTRYPOINT ["ruby", "website/server.rb"]
