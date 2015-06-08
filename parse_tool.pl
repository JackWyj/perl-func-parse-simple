use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor;
my @warnlib = qw(strict warnings);

if($^O eq 'MSWin32'){
    eval "use Win32::Console::ANSI";
}

sub print_msg{
    my ($msg, $color) = @_;
    print color "$color";
    print $msg;
    print color 'reset';
}

sub read_file{
    my ($file) = @_;
    die "file cann't be undef" unless defined $file;
    die "file($file)doesn't exist" unless -f $file;
    open(FILE, $file) or die "open file($file)error: $!";
    my @content = <FILE>;
    close(FILE);
    return wantarray ? @content : \@content;
}

sub get_func_tag{
    my ($content) = @_;
    my $func_tag = {};
    my $lib_tag = {};
    
    my $linum = 0;
    my $pre;
    
    foreach my $line (@$content){
        $linum++;
        next if $line =~ m/^\s*#.+/;
        if($line =~ m/^\}/){
            if (exists $func_tag->{$pre}){
                $func_tag->{$pre}->{end} = $linum;
                $pre = undef;
            }
        }
        if($line =~ m/sub ([^\(\{]+)[\(\{]/){
            my $m = $1;
            $m =~ s/\s+//;
            $func_tag->{$m} = {};
            $func_tag->{$m}->{start} = $linum;
            $pre = $m;
            next;
        }
        if($line =~ m/^use (.+?);/){
            my $m = $1;
            next if($m =~ m/^constant\s+/);
            if($m =~ m/qw\((.+)\)/){
                my $m2 = $1;
                my @f = split(' ', $m2);
                foreach my $e (@f){
                    $func_tag->{$e} = {};
                    $func_tag->{$e}->{start} = $linum;
                }
            }
            if($m =~ m/(.+?)::/){
                my $fpre = $1;
                $lib_tag->{$fpre} = $linum;
            }
            $m =~ s/ qw\(.+\)//;
            next if $m ~~ @warnlib;
            $lib_tag->{$m} = $linum;
        }

        
    }
    print Dumper $func_tag;
    return wantarray ? ($func_tag, $lib_tag) : $func_tag;
}

sub flow{
    my ($content, $func, $func_tag, $lib_tag) = @_;

    return {}
        unless exists $func_tag->{$func};
    die "content isn't ref of ARRAY"
        unless ref($content) eq 'ARRAY';
    die "content is empty" unless @$content;
    my $linum = $func_tag->{$func}->{start};
    my $end = $func_tag->{$func}->{end};

    my $flow = [];
    my $call_graph = {};

    for(my $i = $linum-1; $i < $end; $i++ ){
        my $line = $content->[$i];
        # print "$i: $line \n";
        next if $line =~ m/^\s*#.+/;
        while($line =~  m/([\w_:]+?)\(/g){
            my $sv = 0;
            # print "m: $1\n";
            my $m = $1;
            if(exists $func_tag->{$m}){
                push @$flow, $m;
                $call_graph->{$m} = {};
                $sv = 1;
            }
            if($sv != 1 and $m =~ m/(.+?)::/){
                my $fpre = $1;
                # print "fpre: $fpre\n";
                if( exists $lib_tag->{$fpre}){
                    $call_graph->{$m} = {};
                    $sv = 1;
                    push @$flow, $m;
                }
            }
            if($sv != 1 and $m =~ m/(.+)::/){
                my $pre = $1;
                # print "pre: $pre\n";
                if( exists  $lib_tag->{$pre}){
                    push @$flow, $m;
                    $call_graph->{$m} = {};
                    $sv = 1;
                }
            }
            
        }
    }

    return $call_graph;
}

my $func_note = {};
sub calltree{
    my ($content, $func, $func_tag, $lib_tag) = @_;
    $func_note->{$func} = 1;
    my $graph = flow($content, $func, $func_tag, $lib_tag);
    foreach my $key (keys %$graph){
        next if exists $func_note->{$key};
        $graph->{$key} = calltree($content, $key, $func_tag, $lib_tag);
    }
    return $graph;
}

sub callgraph{
    my ($content, $func, $func_tag, $lib_tag) = @_;
    print_msg("$func\n", 'bold yellow');
    my $graph = calltree($content, $func, $func_tag, $lib_tag);
    $func_note = {};
    print Dumper $graph;
}

sub print_all_func{
    my ($func) = @_;
    
    die "func can't be undef" unless defined $func;
    die "func isn't ref of HASH" unless ref($func) eq 'HASH';
    
    print Dumper $func;
}

sub print_help{
    my $help = << 'HELP';
usage: 
    quit or q  : to exit the program
    func       : to enter the <Func-parse> mode
    ...
   ( to be continue )
HELP
    ;
    print $help;
}

sub print_func_help{
    my $help = << 'HELP';
usage:
    quit or q  :  to exit the program
    allfunc    :  show all functinos
    alllib     :  show all libs
    flow       :  show the call graph of a function
HELP
;
    print $help;
}

sub cli_func_ctrl{
    my ($input, $func_tag, $lib_tag, $content) = @_;
    
    return -1 if $input eq 'q' or $input eq 'quit';
    print_all_func($func_tag) if $input eq 'allfunc';
    print_all_func($lib_tag) if $input eq 'alllib';
    
    if($input eq 'flow'){
        print "input function to parse: ";
        my $func;
        while(1){
            $func = <stdin>;
            chomp $func;
            last if exists $func_tag->{$func};
            print "function ($func) doesn't exist, input again: "
        }
        callgraph($content, $func, $func_tag, $lib_tag);
    }elsif($input eq 'h' or $input eq 'help'){
        print_func_help();
    }
    
}
sub cli_func{
    print "input file (*.pl) to parse: ";
    my $file;
    while(1){
        $file = <stdin>;
        chomp $file;
        last if -f $file;
        print "file ($file) doesn't exist, input again: ";
    }
    my $content = read_file($file);
    my ($func, $lib) = get_func_tag($content);
    while(1){
        print_msg('Func-parse> ', 'bold red');
        my $input = <stdin>;
        chomp $input;
        my $ret = cli_func_ctrl($input, $func, $lib, $content);
        return -1 if defined $ret and $ret == -1;
    }
}

sub cli{
    my $input;
    my $param;
    
    while(1){
        print_msg('Kilr> ', 'bold green');
        $input = <stdin>;
        chomp $input;
        cli_getopt($input);
    }
}

sub cli_getopt{
    my ($str) = @_;
    if( $str eq 'func'){
        my $ret = cli_func();
        # return if $ret == -1;
    }elsif( $str eq 'h' or $str eq 'help'){
        print_help();
    }elsif( $str eq 'q' or $str eq 'quit'){
        exit -1;
    }
}

cli();

my $book = {};
sub mark{
    my($key, $func);
    die "key can't be undef"  unless defined $key;
    die "($func) isn't ref of CODE"
	unless ref($func) eq 'CODE';
    $book->{$key} = $func;
}

sub read_book{
    my($key) = @_;
    die "key can't be undef" unless defined $key;
    die "the function mapped to key ($key) doesn't exist"
	unless exists $book->{$key};
    $book->{$key}->();
}

sub destroy_book{
    $book = {};
}


