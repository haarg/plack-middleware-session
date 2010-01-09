package Plack::Middleware::Session::Cookie;
use strict;
use parent qw(Plack::Middleware::Session);

use Plack::Util::Accessor qw(secret session_key domain expires path secure);

use Digest::HMAC_SHA1;
use MIME::Base64 ();
use Storable ();
use Time::HiRes;
use Plack::Util;

use Plack::Session::State::Cookie;

sub prepare_app {
    my $self = shift;

    Plack::Util::load_class($self->session_class) if $self->session_class;
    $self->session_key("plack_session") unless $self->session_key;

    $self->state( Plack::Session::State::Cookie->new );
    for my $attr (qw(session_key path domain expires secure)) {
        $self->state->$attr($self->$attr);
    }
}

sub get_session {
    my($self, $request) = @_;

    my $cookie = $self->state->get_session_id($request) or return;

    my($time, $b64, $sig) = split /:/, $cookie, 3;
    $self->sig($b64) eq $sig or return;

    my $session = Storable::thaw(MIME::Base64::decode($b64));
    return ($time, $session);
}

sub generate_id {
    my $self = shift;
    return Time::HiRes::gettimeofday;
}

sub commit { }

sub save_state {
    my($self, $id, $res, $session, $options) = @_;

    my $cookie = $self->_serialize($id, $session);
    $self->state->finalize($cookie, $res, $options);
}

sub _serialize {
    my($self, $id, $session) = @_;

    my $b64 = MIME::Base64::encode( Storable::freeze($session), '' );
    join ":", $id, $b64, $self->sig($b64);
}

sub sig {
    my($self, $b64) = @_;
    return '.' unless $self->secret;
    Digest::HMAC_SHA1::hmac_sha1_hex($b64, $self->secret);
}

1;

__END__

=head1 NAME

Plack::Middleware::Session::Cookie - Session middleware that saves session data in the cookie

=head1 SYNOPSIS

  enable "Session::Cookie";

=head1 DESCRIPTION

This middleware component allows you to use the cookie as a sole
cookie state and store, without any server side storage to do the
session management. This middleware utilizes its own state and store
automatically for you, so you can't override the objects.

=head1 CONFIGURATIONS

This middleware is a subclass of L<Plack::Middleware::Session> and
accepts most configuration of the parent class. In addition, following
options are accepted.

=over 4

=item secret

Server side secret to sign the session data using HMAC SHA1. Defaults
to nothing (i.e. do not sign) but B<strongly recommended> to set your
own secret string.

=item session_key, domain, expires, path, secure

Accessors for the cookie attribuets. See
L<Plack::Session::State::Cookie> for these options.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa

=head1 SEE ALSO

Rack::Session::Cookie L<Dancer::Session::Cookie>

=cut

