package utils;

use base Exporter;
use Exporter;
use strict;
use testapi;

our @EXPORT = qw(switch_to_x11 wait_for_desktop ensure_unlocked_desktop);

sub switch_to_x11 {
    my @hdd = split(/-/, get_required_var('HDD_1'));
    # older openSUSE Tumbleweed has x11 still on tty7
    my $x11_tty = $hdd[3] < 20190617 ? 'f7' : 'f2';
    send_key "ctrl-alt-$x11_tty";
}

sub wait_for_desktop {
    assert_screen([qw/boot-menu openqa-desktop/]);
    if (match_has_tag('boot-menu')) {
        send_key 'ret';
    }
    assert_screen 'openqa-desktop', 500;
    if (match_has_tag('openqa-desktop-locked')) {
        send_key 'esc';
        wait_still_screen(1);
        type_string $testapi::password . "\n";
        assert_screen 'openqa-desktop';
    }
    elsif (match_has_tag('openqa-desktop-login')) {
        assert_and_click 'openqa-desktop-login';
        wait_still_screen(1);
        type_string $testapi::password . "\n";
        assert_screen 'openqa-desktop';
    }
}


# if stay under tty console for long time, then check
# screen lock is necessary when switch back to x11
# all possible options should be handled within loop to get unlocked desktop
sub ensure_unlocked_desktop {
    my $counter = 10;
    while ($counter--) {
        assert_screen [qw(displaymanager displaymanager-password-prompt generic-desktop screenlock gnome-screenlock-password)], no_wait => 1;
        if (match_has_tag 'displaymanager') {
            if (check_var('DESKTOP', 'minimalx')) {
                type_string "$username";
                save_screenshot;
            }
            send_key 'ret';
        }
        if ((match_has_tag 'displaymanager-password-prompt') || (match_has_tag 'gnome-screenlock-password')) {
            type_password;
            send_key 'ret';
        }
        if (match_has_tag 'generic-desktop') {
            send_key 'esc';
            unless (get_var('DESKTOP', '') =~ m/minimalx|awesome|enlightenment|lxqt|mate/) {
                # gnome might show the old 'generic desktop' screen although that is
                # just a left over in the framebuffer but actually the screen is
                # already locked so we have to try something else to check
                # responsiveness.
                # open run command prompt (if screen isn't locked)
                mouse_hide(1);
                send_key 'alt-f2';
                if (check_screen 'desktop-runner') {
                    send_key 'esc';
                    assert_screen 'generic-desktop';
                }
                else {
                    next;    # most probably screen is locked
                }
            }
            last;            # desktop is unlocked, mission accomplished
        }
        if (match_has_tag 'screenlock') {
            wait_screen_change {
                send_key 'esc';    # end screenlock
            };
        }
        wait_still_screen 2;       # slow down loop
        die 'ensure_unlocked_desktop repeated too much. Check for X-server crash.' if ($counter eq 1);    # die loop when generic-desktop not matched
    }
}

1;
