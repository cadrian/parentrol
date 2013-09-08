#!/usr/bin/awk -f

BEGIN {
    h = 24;
    m = 0;
    t = 0;
}

$2 ~ /tty[0-9]+/ && /still logged in/ {
    split($6, a, ":");
    H = strtonum(a[1]);
    M = strtonum(a[2]);
    if ((H < h) || (H == h && M < m)) {
	h = H;
	m = M;
    }
}

$2 ~ /tty[0-9]+/ && $7 == "-" && $8 ~ /[0-9]+:[0-9]+/ {
    split($6, a, ":");
    BH = strtonum(a[1]);
    BM = strtonum(a[2]);
    split($8, a, ":");
    EH = strtonum(a[1]);
    EM = strtonum(a[2]);
    t += (EH * 60 + EM) - (BH * 60 + BM);
}

{
    next;
}

END {
    if (h == 24) {
	t = strtonum(ENVIRON["NOW"]);
    } else {
	t += (h * 60 + m) - strtonum(ENVIRON["NOW"]);
    }
    printf("%d\n", t);
}
