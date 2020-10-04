#!/bin/sh -x

sudo make install && \
    sudo cp templates/* /usr/local/odd-sundays/templates/ && \
    sudo cp static/* /var/www/html/odd-sundays-static/
    sudo service httpd reload
