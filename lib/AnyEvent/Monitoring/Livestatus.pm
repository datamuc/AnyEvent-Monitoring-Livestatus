# ABSTRACT: event based livestatus client
use common::sense;
package AnyEvent::Monitoring::Livestatus;
use namespace::autoclean;
use Moo;
use AnyEvent;
use AnyEvent::Handle;

our $VERSION = '0.000001';

has socket => (
    is => 'ro',
);

sub get_hdl {
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

sub _send {
    my ($self, $query, $cb) = @_;
    # The fixed16 is not needed, because JSON texts are fully self-delimiting,
    # AnyEvent::Handle will handle that already for us
    # TODO: Well, it's needed for the status code, implement that later
    $query .= "\nOutputFormat: json\n\n";

    my $cv = AE::cv;
    my $json;
    my $hdl = $self->get_hdl;

    $hdl->push_write($query);

    my $reader; $reader = sub {
        my ($hdl, $data) = @_;

        # If a callback was given, we call it with the result
        # If no callback was given we emulate a synchronous api
        # and return the data
        #$self->_clear_hdl;
        #$hdl->destroy;
        if($cb) {
            $cb->($data);
            $cv->send;
        } else {
            $cv->send($data);
        }

    };

    $hdl->push_read(json => $reader);

    # If a callback was given, we call it with the result
    # If no callback was given we emulate a synchronous api
    # and return the data
    $cb ? $cv : $cv->recv;
}

1;
