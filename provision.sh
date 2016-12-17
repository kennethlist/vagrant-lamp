#!/bin/bash

APACHE_CONFIG_FILE="/etc/apache2/envvars"
APACHE_VHOST_FILE="/etc/apache2/sites-available/vagrant_vhost.conf"
PHP_CONFIG_FILE="/etc/php/7.0/apache2/php.ini"
XDEBUG_CONFIG_FILE="/etc/php/7.0/mods-available/xdebug.ini"
MYSQL_CONFIG_FILE="/etc/mysql/my.cnf"
DEFAULT_APACHE_INDEX="/var/www/html/index.html"
PROJECT_WEB_ROOT="www"
USER_HOME="/home/vagrant"
DBHOST="localhost"
DBNAME="vagrant"
DBUSER="root"
DBPASSWD="vagrant"

# This function is called at the very bottom of the file
main() {
  echo "Seting up environment. This may take a few minutes..."
  perform_update
  install_core_components
  install_apache
  install_mysql
  install_php
  install_mailhog
  echo ""
  echo "Environment is now setup."
  echo ""
}

perform_update() {
  # Update the server
  apt-get -qq update
  # apt-get -y upgrade
}

cleanup() {
  apt-get -y autoremove
}

install_core_components() {
  echo "Installing core components..."
  # Install basic tools
  apt-get -y install build-essential git
}

install_apache() {
  # Install Apache
  echo "Installing Apache..."
  apt-get -y install apache2

  sed -i "s/^\(.*\)www-data/\1ubuntu/g" ${APACHE_CONFIG_FILE}
  chown -R ubuntu:ubuntu /var/log/apache2

  if [ ! -f "${APACHE_VHOST_FILE}" ]; then
    cat << EOF > ${APACHE_VHOST_FILE}
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /vagrant/${PROJECT_WEB_ROOT}
    LogLevel debug

    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined

    <Directory /vagrant/${PROJECT_WEB_ROOT}>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
  fi

  a2dissite 000-default
  a2ensite vagrant_vhost

  a2enmod rewrite

  systemctl enable apache2
  systemctl reload apache2
}

install_php() {
  echo "Installing PHP..."
  apt-get -y install php php-gd php-mysql php-mcrypt php-curl php-intl php7.0-xsl php-mbstring php-zip php-bcmath php-xdebug php-soap

  sed -i "s/display_startup_errors = Off/display_startup_errors = On/g" ${PHP_CONFIG_FILE}
  sed -i "s/display_errors = Off/display_errors = On/g" ${PHP_CONFIG_FILE}

  # sed -i "s/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_ALL/g" ${PHP_CONFIG_FILE}
  sed -i "s/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 36000/g" ${PHP_CONFIG_FILE}
   
  apt-get -y install graphviz # dep for webgrind

  if [ ! -f "{$XDEBUG_CONFIG_FILE}" ]; then
    cat << EOF > ${XDEBUG_CONFIG_FILE}
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_port=9000
xdebug.remote_host=10.0.2.2
xdebug.profiler_enable_trigger=1;
xdebug.profiler_output_dir=/tmp
EOF
  fi

  systemctl reload apache2

  # Install latest version of Composer globally
  if [ ! -f "/usr/local/bin/composer" ]; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  fi

  # Install PHP Unit 4.8 globally
  # if [ ! -f "/usr/local/bin/phpunit" ]; then
  #   curl -O -L https://phar.phpunit.de/phpunit-old.phar
  #   chmod +x phpunit-old.phar
  #   mv phpunit-old.phar /usr/local/bin/phpunit
  # fi
}

install_mysql() {
  # Install MySQL
  echo "Installing MySQL..."
  echo "mysql-server mysql-server/root_password password $DBPASSWD" | debconf-set-selections
  echo "mysql-server mysql-server/root_password_again password $DBPASSWD" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/app-password-confirm password $DBPASSWD" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DBPASSWD" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/app-pass password $DBPASSWD" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | debconf-set-selections
  apt-get -y install mysql-client mysql-server phpmyadmin

  echo "\$cfg['LoginCookieValidity'] = 36000;" >> /etc/phpmyadmin/config.inc.php
  
  mysql -uroot -p$DBPASSWD -e "CREATE DATABASE $DBNAME"
  mysql -uroot -p$DBPASSWD -e "grant all privileges on $DBNAME.* to '$DBUSER'@'localhost' identified by '$DBPASSWD'"
  
  sed -i "s/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" ${MYSQL_CONFIG_FILE}

  # Allow root access from any host
  echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'vagrant' WITH GRANT OPTION" | mysql -u root --password=$DBPASSWD
  echo "GRANT PROXY ON ''@'' TO 'root'@'%' WITH GRANT OPTION" | mysql -u root --password=$DBPASSWD

  # if [ -d "/vagrant/provision-sql" ]; then
  #   echo "Executing all SQL files in /vagrant/provision-sql folder ..."
  #   echo "-------------------------------------"
  #   for sql_file in /vagrant/provision-sql/*.sql
  #   do
  #     echo "EXECUTING $sql_file..."
  #       time mysql -u root --password=root < $sql_file
  #       echo "FINISHED $sql_file"
  #       echo ""
  #   done
  # fi

  systemctl restart mysql
}


install_mailhog() {
  echo "Installing MailHog..."
  apt-get -y install golang
  # echo "GOPATH=\$HOME/go" >> ${USER_HOME}/.bashrc
  # echo "PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin" >> ${USER_HOME}/.bashrc
  sudo su - ubuntu /bin/bash -c "export GOPATH=\$HOME/go; export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin; go get github.com/mailhog/mhsendmail"
  echo "sendmail_path = /home/ubuntu/go/bin/mhsendmail" >> ${PHP_CONFIG_FILE}
  
  # Download binary from github
  sudo su - ubuntu -c "wget --quiet -O ~/mailhog https://github.com/mailhog/MailHog/releases/download/v0.1.8/MailHog_linux_amd64 && chmod +x ~/mailhog"
    
  # Make it start on reboot
  tee /etc/systemd/system/mailhog.service <<EOL
[Unit]
Description=MailHog Service
After=network.service vagrant.mount
[Service]
Type=simple
ExecStart=/usr/bin/env /home/ubuntu/mailhog > /dev/null 2>&1 &
[Install]
WantedBy=multi-user.target
EOL

  # Start on reboot
  systemctl enable mailhog

  # Start background service now
  systemctl start mailhog

  service apache2 restart
}

main
exit 0
