package GreenBucket::Agent;

use strict;
use warnings;
use GreenBucket;
use Coro;
use Coro::Select;
use Furl;
use Net::DNS::Lite qw//;
use Log::Minimal;
use MIME::Base64;
use Class::Accessor::Lite (
    new => 1,
    ro  => [qw/user passwd/]
);

sub furl {
    my $self = shift;

    my $user = $self->user;
    my $passwd = $self->passwd;

    my @headers;
    if ( $user && $passwd ) {
        push @headers , 'Authorization', 'Basic ' . MIME::Base64::encode("$user:$passwd", '');
    }

    $self->{furl} ||= Furl->new(
        inet_aton => \&Net::DNS::Lite::inet_aton,
        timeout   => 10,
        agent => 'GreenBucketAgent/$GreenBucket::VERSION',
        headers => @headers,
    );
}

sub get {
    my $self = shift;
    my @url = @_;
    my $res;
    for my $url ( @url ) {
        $res = $self->furl->get($url);
        infof("failed get: %s / %s", $url, $res->status_line) if ! $res->is_success;
        last if $res->is_success; 
    }
    return $res;
}

sub put {
    my $self = shift;
    my $urls = shift;
    my $content_ref = shift;
 
    my @coros;
    for my $url ( @$urls ) {
        push @coros, async {
            debugf("put: %s", $url);
            my $res = $self->furl->put( $url, [], $$content_ref );
            infof("failed put: %s / %s", $url, $res->status_line) if ! $res->is_success;
            push @res, $res;
        };
    }

    $_->join for @coros;

    my @success = grep { $_->is_success } @res;
    return @success == @$urls;
}

sub delete {
    my $self = shift;
    my $urls = shift;

    my @coros;
    for my $url ( @$urls ) {
        push @coros, async {
            my $res = $self->furl->delete( $url );
            debugf("delete: %s / %s", $url, $res->status_line);
        };
    }

    $_->join for @coros;
    return;
}

1;

