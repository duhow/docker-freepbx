FROM debian:testing
LABEL maintainer "contacto@duhowpi.net"

RUN echo "deb http://deb.debian.org/debian jessie-backports main" >> /etc/apt/sources.list

RUN apt-get update
RUN apt-get upgrade -y

# linux-headers-`uname -r`

WORKDIR /tmp
RUN echo "mysql-server mysql-server/root_password password rootpbx" > tmpcommand
RUN echo "mysql-server mysql-server/root_password_again password rootpbx" >> tmpcommand
RUN debconf-set-selections < tmpcommand
RUN rm tmpcommand

RUN apt-get install -y build-essential openssh-server apache2 mysql-server \
	mysql-client bison flex php php-odbc php-curl php-cli php-mysql php-pear php-gd curl sox \
	libncurses5-dev libssl-dev libmysqlclient-dev libxml2-dev libnewt-dev libsqlite3-dev \
	libasound2-dev libogg-dev libvorbis-dev libical-dev libneon27-dev libsrtp0-dev libspandsp-dev \
	python-dev unixodbc-dev uuid-dev python autoconf git uuid libcurl4-openssl-dev \
	mpg123 sqlite3 \
	pkg-config apt-utils automake libtool libtool-bin texinfo wget curl \
 	sudo subversion libltdl7 libmysqlclient18 mysql-common odbcinst odbcinst1debian2 \
	aptitude aptitude-common libboost-filesystem1.62.0 libboost-iostreams1.62.0 \
	libboost-system1.62.0 libclass-accessor-perl libcwidget3v5 libio-string-perl \
	libparse-debianchangelog-perl libsigc++-2.0-0v5 libsub-name-perl libxapian30

RUN apt-get install -y --allow-downgrades openssl=1.0.2k-1~bpo8+1 libssl-dev=1.0.2k-1~bpo8+1

WORKDIR /tmp
RUN wget http://ftp.debian.org/debian/pool/main/m/myodbc/libmyodbc_5.1.10-3_amd64.deb
RUN dpkg -i libmyodbc_5.1.10-3_amd64.deb
RUN apt-get install -f
RUN rm libmyodbc_5.1.10-3_amd64.deb

# RUN pear install Console_Getopt # Already installed

WORKDIR /usr/src
RUN git clone https://github.com/meduketto/iksemel.git
WORKDIR iksemel
RUN ./autogen.sh
RUN ./configure
RUN make
RUN make install
RUN ldconfig

# RUN wget http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
# RUN wget http://downloads.asterisk.org/pub/telephony/libpri/libpri-current.tar.gz

WORKDIR /usr/src
RUN wget http://www.pjsip.org/release/2.6/pjproject-2.6.tar.bz2
RUN tar xjvf pjproject*.tar.bz2
WORKDIR pjproject-2.6
RUN CFLAGS='-DPJ_HAS_IPV6=1' ./configure --enable-shared --disable-sound --disable-resample --disable-video --disable-opencore-amr
RUN make dep
RUN make
RUN make install

WORKDIR /usr/src
RUN wget -O jansson-2.9.tar.gz https://github.com/akheron/jansson/archive/v2.9.tar.gz
RUN tar xzvf jansson-2.9.tar.gz
WORKDIR jansson-2.9
RUN autoreconf -i
RUN ./configure
RUN make
RUN make install

WORKDIR /usr/src
RUN wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-14.2.1.tar.gz
RUN tar xzvf asterisk*.tar.gz
RUN rm *.tar.gz
WORKDIR asterisk-14.2.1
RUN contrib/scripts/get_mp3_source.sh

# Configuring libvpb1
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get install -q -y libvpb1

RUN contrib/scripts/install_prereq install
RUN ./configure
RUN make menuselect.makeopts
RUN menuselect/menuselect --enable format_mp3 menuselect.makeopts

RUN make
RUN make install
RUN make config
RUN ldconfig
RUN update-rc.d -f asterisk remove

WORKDIR /var/lib/asterisk/sounds
RUN wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-wav-current.tar.gz
RUN wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-g722-current.tar.gz
RUN wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-wav-current.tar.gz
RUN wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-g722-current.tar.gz
RUN tar xzvf asterisk-core-sounds-en-wav-current.tar.gz
RUN tar xzvf asterisk-core-sounds-en-g722-current.tar.gz
RUN tar xzvf asterisk-extra-sounds-en-wav-current.tar.gz
RUN tar xzvf asterisk-extra-sounds-en-g722-current.tar.gz
RUN rm -f *.tar.gz

RUN useradd -m asterisk
RUN chown asterisk. /var/run/asterisk
RUN chown -R asterisk. /etc/asterisk
RUN chown -R asterisk. /var/lib/asterisk
RUN chown -R asterisk. /var/log/asterisk
RUN chown -R asterisk. /var/spool/asterisk
RUN chown -R asterisk. /usr/lib/asterisk
RUN rm -rf /var/www/html

RUN sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.0/apache2/php.ini
RUN cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig
RUN sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
RUN sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

ADD odbcinst.ini /etc/odbcinst.ini
ADD odbc.ini /etc/odbc.ini

WORKDIR /usr/src
RUN wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-13.0-latest.tgz
RUN tar xzvf freepbx-13.0-latest.tgz
RUN rm freepbx*.tgz
WORKDIR freepbx
RUN service apache2 restart && \
	service mysql restart && \
	./start_asterisk start && \
	./install --dbpass="rootpbx" -n

EXPOSE 80 443 5060/udp 5061/udp
