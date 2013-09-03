#!/usr/bin/perl -w
my $path = "/mmt/wfsdat/";
# my @years = ('2005','2004','2003');
my @years = ('2013');
foreach ( @years ) {
    my $year = $_;
    for (my $m = 1; $m <= 1; $m++) {
        $month = $m;
        $month = "0" . $month if $month < 10;
        for (my $day = 1; $day <= 31; $day++) {
            my $d = $day;
            $d = "0" . $d if $d < 10;
            my $curdir = $path . $year . $month . $d;
            print $curdir . "\n";
            chdir($curdir) or next;
            opendir (DIR, ".") or next;
            my @files = grep {/\.fits$/} readdir DIR;
            close DIR;
            print "pwd = " . `pwd`;
            foreach (@files) {
                print "/mmt/shwfs/seeing_mysql.pl $year-$month-$d $_\n";
                print `/mmt/shwfs/seeing_mysql.pl $year-$month-$d $_`;
            }
        }
    }
}
