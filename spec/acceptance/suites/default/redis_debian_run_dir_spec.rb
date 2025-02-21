# frozen_string_literal: true

require 'spec_helper_acceptance'

# since this test polutes others, we'll only run it if specifically asked
if ENV['RUN_BACKPORT_TEST'] == 'yes'
  describe 'redis', if: (fact('operatingsystem') == 'Debian') do
    it 'runs with newer Debian package' do
      pp = <<-EOS

      include ::apt

      class {'::apt::backports':}
      ->
      file { '/usr/sbin/policy-rc.d':
        ensure  => present,
        content => "/usr/bin/env sh\nexit 101",
        mode    => '0755',
      }
      ->
      package { 'redis-server':
        ensure => 'latest',
        install_options => {
          '-t' => "${::lsbdistcodename}-backports",
        },
      }
      ->
      class { 'redis':
        manage_package => false,
      }
      EOS

      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_change: true)
    end

    describe package('redis-server') do
      it { is_expected.to be_installed }
    end

    describe service('redis-server') do
      it { is_expected.to be_running }
    end

    context 'redis should respond to ping command' do
      describe command('redis-cli ping') do
        its(:stdout) { is_expected.to match %r{PONG} }
      end
    end

    context 'redis log should be clean' do
      describe command('journalctl --no-pager') do
        its(:stdout) { is_expected.not_to match %r{Failed at step RUNTIME_DIRECTORY} }
      end
    end
  end
end
