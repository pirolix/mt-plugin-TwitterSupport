package MT::Plugin::OMV::TwitterSupport;
# $Id$

use strict;
use MT 4;
use MT::Blog;
use MT::Entry;
use MT::Template;
use MT::Util;

use constant DEFAULT_FORMAT => q(<$mt:entrytitle$> <$mt:entrypermalink tinyurl="1"$>);

use vars qw( $VENDOR $MYNAME $VERSION );
($VENDOR, $MYNAME) = (split /::/, __PACKAGE__)[-2, -1];
(my $revision = '$Rev$') =~ s/\D//g;
$VERSION = '0.02'. ($revision ? ".$revision" : '');

use base qw( MT::Plugin );
my $plugin = __PACKAGE__->new({
        id => $MYNAME,
        key => $MYNAME,
        name => $MYNAME,
        version => $VERSION,
        author_name => 'Open MagicVox.net',
        author_link => 'http://www.magicvox.net/',
        doc_link => 'http://www.magicvox.net/archive/2010/04031406/',
        description => <<HTMLHEREDOC,
<__trans phrase="Add a link to post your twit to twitter easily.">
HTMLHEREDOC
});
MT->add_plugin( $plugin );

sub instance { $plugin; }

### Registry
sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        callbacks => {
            'MT::App::CMS::template_source.edit_category' => \&_edit_category_source,
            'MT::App::CMS::template_param.edit_category' => \&_edit_category_param,
            'CMSPostSave.category' => \&_hdlr_save_category,

            'MT::App::CMS::template_source.edit_entry' => sub {
                5.0 <= $MT::VERSION
                    ? _edit_entry_source_v5 (@_)
                    : 4.0 <= $MT::VERSION
                        ? _edit_entry_source_v4 (@_)
                        : undef;
            },
            'MT::App::CMS::template_param.edit_entry' => \&_edit_entry_param,
        },
    });
}



### template_source.edit_category
sub _edit_category_source {
    my ($eh_ref, $app_ref, $tmpl_ref) = @_;

    my $old = quotemeta (<<'HTMLHEREDOC');
<mt:setvarblock name="action_buttons">
HTMLHEREDOC
    my $new = << 'HTMLHEREDOC';
    <fieldset>
        <h3><__trans phrase="Twitter Support"></h3>
<mtapp:setting
    id="twicco_support"
    label="<__trans phrase="Format">">
  <input type="text" name="twicco_support" value="<mt:var name="twicco_support" escape="html">" class="full-width wide" />
</mtapp:setting>
    </fieldset>
HTMLHEREDOC
    $$tmpl_ref =~ s/($old)/$new$1/;
}

### template_param.edit_category
sub _edit_category_param {
    my ($cb, $app, $param, $tmpl) = @_;

    my $data = load_plugindata ($param->{blog_id}) || {};
    $param->{twicco_support} = defined $data->{$param->{id}}
            ? $data->{$param->{id}}
            : DEFAULT_FORMAT;
}

### CMSPostSave.category
sub _hdlr_save_category {
    my ($cb, $app, $category) = @_;

    if (defined (my $twicco_support = $app->param ('twicco_support'))) {
        my $data = load_plugindata ($category->blog_id) || {};
        $data->{$category->id} = $twicco_support || '';
        save_plugindata ($category->blog_id, $data);
    }
}



### template_source.edit_entry for MT5.x
sub _edit_entry_source_v5 {
    my ($eh_ref, $app_ref, $tmpl_ref) = @_;

    my $old = quotemeta (<<'HTMLHEREDOC');
    </mtapp:widget>
</div>

<mt:if name="object_type" like="(entry|page)">
HTMLHEREDOC
    my $new = << 'HTMLHEREDOC';
<mt:if name="twitter_url">
        <mtapp:setting
            id="twitter_url"
            label="<__trans phrase="Twitter">"
            label_class="top-label">
<a href="<$mt:var name="twitter_url"$>" target="twitter"><__trans phrase="Post a tweet."></a>
        </mtapp:setting>
</mt:if>
HTMLHEREDOC
    $$tmpl_ref =~ s/($old)/$new$1/;
}

### template_source.edit_entry for MT4.x
sub _edit_entry_source_v4 {
    my ($eh_ref, $app_ref, $tmpl_ref) = @_;

    my $old = quotemeta (<<'HTMLHEREDOC');
    </mtapp:widget>
    <mt:if name="agent_ie"><div>&nbsp;<!-- IE Duplicate Characters Bug -->&nbsp;</div></mt:if>
HTMLHEREDOC
    my $new = << 'HTMLHEREDOC';
<mt:if name="twitter_url">
        <mtapp:setting
            id="twitter_url"
            label="<__trans phrase="Twitter">">
<a href="<$mt:var name="twitter_url"$>" target="twitter"><__trans phrase="Post a tweet."></a>
        </mtapp:setting>
</mt:if>
HTMLHEREDOC
    $$tmpl_ref =~ s/($old)/$new$1/;
}

### template_param.edit_entry
sub _edit_entry_param {
    my ($cb, $app, $param) = @_;

    my $blog_id = $param->{blog_id}
        or return;
    my $blog = MT::Blog->load ($blog_id)
        or return; # no blog
    my $id = $param->{id}
        or return;
    my $entry = MT::Entry->load ($id)
        or return; # no entry
    my $category = $entry->category
        or return; # not selected category

    my $tmpl = MT::Template->new;
    my $ctx = $tmpl->context;
    $ctx->stash ('blog', $blog);
    $ctx->stash ('entry', $entry);

    my $data = load_plugindata ($blog_id) || {};
    $tmpl->text ($data->{$category->id} || DEFAULT_FORMAT);
    my $output = $tmpl->output
        or return; # no output
    $output = MT::Util::encode_url ($output);

    $param->{twitter_url} = "http://twitter.com/home?status=$output";
}

########################################################################
use MT::PluginData;

sub save_plugindata {
    my ($key, $data_ref) = @_;
    my $pd = MT::PluginData->load({ plugin => &instance->id, key=> $key });
    if (!$pd) {
        $pd = MT::PluginData->new;
        $pd->plugin( &instance->id );
        $pd->key( $key );
    }
    $pd->data( $data_ref );
    $pd->save;
}

sub load_plugindata {
    my ($key) = @_;
    my $pd = MT::PluginData->load({ plugin => &instance->id, key=> $key })
        or return undef;
    $pd->data;
}

1;