package Zing::Store::Rocks;

use 5.014;

use strict;
use warnings;

use registry 'Zing::Types';
use routines;

use Data::Object::Class;
use Data::Object::ClassHas;

extends 'Zing::Store';

use File::Spec;
use RocksDB;

# VERSION

# ATTRIBUTES

has root => (
  is => 'ro',
  isa => 'Str',
  new => 1,
);

fun new_root($self) {
  my $root = File::Spec->catfile(
    File::Spec->curdir, 'zing',
  );
  mkdir $root;
  $root
}

has client => (
  is => 'ro',
  isa => 'InstanceOf["RocksDB"]',
  new => 1,
);

fun new_client($self) {
  RocksDB->new($self->root, {create_if_missing => 1})
}

# BUILDERS

fun new_encoder($self) {
  require Zing::Encoder::Dump; Zing::Encoder::Dump->new;
}

# METHODS

method drop(Str $key) {
  return int(!!$self->client->delete($key));
}

method keys(Key $query) {
  my $results = [];
  my $regexp = $query =~ s/\*/.*/gr;
  my $iterator = $self->client->new_iterator->seek_to_first;
  while (my ($key, $value) = $iterator->each) {
      if ($key =~ /^$regexp$/) {
        push @$results, $key;
      }
  }
  return $results;
}

method lpull(Str $key) {
  if (my $data = $self->recv($key)) {
    my $result = shift @{$data->{list}};
    $self->send($key, $data);
    return $result;
  }
  else {
    return undef;
  }
}

method lpush(Str $key, HashRef $val) {
  if (my $data = $self->recv($key)) {
    my $result = unshift @{$data->{list}}, $val;
    $self->send($key, $data);
    return $result;
  }
  else {
    my $data = {list => []};
    my $result = unshift @{$data->{list}}, $val;
    $self->send($key, $data);
    return $result;
  }
}

method recv(Str $key) {
  my $data = $self->client->get($key);
  return $data ? $self->decode($data) : $data;
}

method rpull(Str $key) {
  if (my $data = $self->recv($key)) {
    my $result = pop @{$data->{list}};
    $self->send($key, $data);
    return $result;
  }
  else {
    return undef;
  }
}

method rpush(Str $key, HashRef $val) {
  if (my $data = $self->recv($key)) {
    my $result = push @{$data->{list}}, $val;
    $self->send($key, $data);
    return $result;
  }
  else {
    my $data = {list => []};
    my $result = push @{$data->{list}}, $val;
    $self->send($key, $data);
    return $result;
  }
}

method send(Str $key, HashRef $val) {
  my $set = $self->encode($val);
  $self->client->put($key, $set);
  return 'OK';
}

method size(Str $key) {
  if (my $data = $self->recv($key)) {
    return scalar(@{$data->{list}});
  }
  else {
    return 0;
  }
}

method slot(Str $key, Int $pos) {
  if (my $data = $self->recv($key)) {
    return $data->{list}[$pos];
  }
  else {
    return undef;
  }
}

method test(Str $key) {
  return $self->recv($key) ? 1 : 0;
}

1;
