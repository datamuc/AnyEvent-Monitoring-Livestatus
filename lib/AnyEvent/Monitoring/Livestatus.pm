# ABSTRACT: event based livestatus client
use common::sense;
package AnyEvent::Monitoring::Livestatus;
use namespace::autoclean;
use Moo;
use AnyEvent;
use AnyEvent::Handle;

our $VERSION = '0.000002';

has socket => (
    is => 'ro',
);

sub _get_hdl {
    my $self = shift;
    AnyEvent::Handle->new(
        connect => $self->socket,
        on_error => sub {
            my ($hdl, $fatal, $msg) = @_;
            die "$fatal: $msg";
        },
        on_eof => sub { warn "eof!" },
    );
}

sub query {
    my ($self, $query, $cb) = @_;

    $query .= "\nOutputFormat: json\nResponseHeader: fixed16\n\n";

    my $return = {};
    my $cv = AE::cv;
    my $hdl = $self->_get_hdl;

    $hdl->push_write($query);

    my $error_cb = sub {
        my $content = $_[1];
        chomp($content);
        $return->{message} = "$content";
        if($cb) {
            $cb->($return);
            $cv->send;
        } else {
            $cv->send($return);
        }
    };

    my $reader = sub {
        my  $data = $_[1];
        $return->{data} = $data;

        # If a callback was given, we call it with the result
        # If no callback was given we emulate a synchronous api
        # and return the data
        #$self->_clear_hdl;
        #$hdl->destroy;
        if($cb) {
            $cb->($return);
            $cv->send;
        } else {
            $cv->send($return);
        }
    };
 
    # read the status line
    $hdl->push_read(line => sub {
        my $line = $_[1];
        my ($num, $length) = (split /\s+/, $line);
        if($num == 200) {
            $return->{code} = $num;
            $return->{message} = "Ok";
            $hdl->push_read(json => $reader);
        } else {
            $return->{code} = $num;
            $hdl->push_read(chunk => $length, $error_cb);
        }
    });

    # If a callback was given, we call it with the result
    # If no callback was given we emulate a synchronous api
    # and return the data
    return $cb ? $cv : $cv->recv;
}

1;
