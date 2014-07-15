#!/usr/bin/awk -f

# Parentrol: parental control
# Copyright (C) 2013-2014 Cyril Adrian <cyril.adrian@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


BEGIN {
    h = 24;
    m = 0;
    t = 0;
}

$2 ~ /:[0-9]+/ && /still logged in/ {
    split($6, a, ":");
    H = strtonum(a[1]);
    M = strtonum(a[2]);
    if ((H < h) || (H == h && M < m)) {
        h = H;
        m = M;
    }
    next;
}

$2 ~ /tty[0-9]+/ && /still logged in/ {
    split($6, a, ":");
    H = strtonum(a[1]);
    M = strtonum(a[2]);
    if ((H < h) || (H == h && M < m)) {
        h = H;
        m = M;
    }
    next;
}

$2 ~ /tty[0-9]+/ && $7 == "-" && $8 ~ /[0-9]+:[0-9]+/ {
    split($6, a, ":");
    BH = strtonum(a[1]);
    BM = strtonum(a[2]);
    split($8, a, ":");
    EH = strtonum(a[1]);
    EM = strtonum(a[2]);
    t += (EH * 60 + EM) - (BH * 60 + BM);
    next;
}

END {
    if (h == 24) {
        t = strtonum(ENVIRON["NOW"]);
    } else {
        t += strtonum(ENVIRON["NOW"]) - (h * 60 + m);
    }
    printf("%d\n", t);
}
