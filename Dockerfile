#Inicio de lo minimo para que corra mi app
FROM php:8-apache

#intalando paquetes que necesitamos de php
RUN echo 'APT::Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    libfcgi-bin \
    libjpeg62-turbo \
    libmariadbd19 \
    libpng16-16 \
    libwebp6 \
    libxpm4 \
    libzip4 \
    openssh-client \
 && rm -rf /var/lib/apt/lists/*

 #Habilitar Apache Mods
 RUN a2enmod rewrite

  # Habilitar la extensión PHP de Redis
RUN yes '' | pecl install -o -f redis \
&&  rm -rf /tmp/pear \
&&  docker-php-ext-enable redis

#Fin de lo minimo para que corra mi app

#Inicio de dependencias de Testing
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
   git \
   libmariadbd-dev \
   libjpeg62-turbo-dev \
   libpng-dev \
   libwebp-dev \
   libxpm-dev \
   libzip-dev \
   python \
   unzip \
   zip




RUN docker-php-ext-install \
   bcmath \
   gd \
   mysqli \
   pdo_mysql \
   zip


#Instalar NodeJS

COPY --from=node:lts-stretch-slim /opt/yarn* /opt/yarn
COPY --from=node:lts-stretch-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=node:lts-stretch-slim /usr/local/include/node /usr/local/include/node
COPY --from=node:lts-stretch-slim /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
 && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
 && ln -s /opt/yarn/bin/yarnpkg /usr/local/bin/yarnpkg \
 && ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx



#install Composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html
# Recibir el ID y el nombre del usuario desarrollador
ARG DEVELOPER_UID=1000
ARG DEVELOPER_USER=developer

# Replicar el usuario dentro del container
RUN addgroup --gid ${DEVELOPER_UID} ${DEVELOPER_USER} \
 ;  useradd -r -m -u ${DEVELOPER_UID} --gid ${DEVELOPER_UID} \
    --shell /bin/bash -c "Developer User,,," ${DEVELOPER_USER}

# Instalar Dependencias de la app ===============================
COPY package*.json /var/www/html/
RUN npm install

COPY composer.* /var/www/html/
RUN composer install --no-scripts --no-interaction --prefer-dist

# Cambiarse al usuario "root" para instalar las dependencias (incluyendo sudo)
USER root

# Instalar sudo, junto con otras dependencias que se requieren durante la fase
# de desarrollo:
RUN apt-get install -y --no-install-recommends \
  # Adding bash autocompletion as git without autocomplete is a pain...
  bash-completion \
  # gpg & gpgconf is used to get Git Commit GPG Signatures working inside the
  # VSCode devcontainer:
  gpg \
  # Para trabajar con la base de datos desde el contenedor de desarrollo:
  mariadb-client \
  # Para esperar a que el servicio de minio (u otros) esté disponible:
  netcat \
  # /proc file system utilities: (watch, ps):
  procps \
  # Vim will be used to edit files when inside the container (git, etc):
  vim \
  # Sudo will be used to install/configure system stuff if needed during dev:
  sudo

  # Agregar el usuario desarrollador a la lista de sudoers:
RUN echo "${DEVELOPER_USER} ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${DEVELOPER_USER}"

# Persistir el historial de bash entre corridas
# - Ver https://code.visualstudio.com/docs/remote/containers-advanced#_persist-bash-history-between-runs
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/command-history/.bash_history" \
    && mkdir /command-history \
    && touch /command-history/.bash_history \
    && chown -R ${DEVELOPER_USER} /command-history \
    && echo $SNIPPET >> "/home/${DEVELOPER_USER}/.bashrc"

# Cambiar al usuario desarrollador:
USER ${DEVELOPER_USER}


