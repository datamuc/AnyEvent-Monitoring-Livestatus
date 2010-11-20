use AnyEvent::Monitoring::Livestatus;
use Data::Dumper::Concise;

my @sockets = (
    [ 'unix/', '/var/tmp/live.icinga' ],
#    [ 'unix/', '/var/tmp/live.nagios' ],
#    [ 'unix/', '/var/tmp/live.shinken' ],
);
my @backends = map {
    AnyEvent::Monitoring::Livestatus->new(
        socket => $_
    )
} @sockets;

my @CV = ();
for my $backend (@backends) {
    push @CV, $backend->_send("GET services", sub {
        print Dumper({socket => $backend->socket, data=> shift});
    });
}
while(my $cv = pop @CV) { $cv->recv }
print '@CV is empty: ', Dumper(\@CV);
