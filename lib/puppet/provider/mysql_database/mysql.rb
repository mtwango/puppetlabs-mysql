# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'mysql'))
Puppet::Type.type(:mysql_database).provide(:mysql, parent: Puppet::Provider::Mysql) do
  desc 'Manages MySQL databases.'

  commands mysql_raw: 'mariadb'

  def self.instances
    mysql_caller('show databases', 'regular').split("\n").map do |name|
      attributes = {}
      mysql_caller(["show variables like '%_database'", name], 'regular').split("\n").each do |line|
        k, v = line.split(%r{\s})
        attributes[k] = v
      end
      new(name: name,
          ensure: :present,
          charset: attributes['character_set_database'],
          collate: attributes['collation_database'])
    end
  end

  # We iterate over each mysql_database entry in the catalog and compare it against
  # the contents of the property_hash generated by self.instances
  def self.prefetch(resources)
    databases = instances
    resources.each_key do |database|
      provider = databases.find { |db| db.name == database }
      resources[database].provider = provider if provider
    end
  end

  def create
    self.class.mysql_caller("create database if not exists `#{@resource[:name]}` character set `#{@resource[:charset]}` collate `#{@resource[:collate]}`", 'regular')

    @property_hash[:ensure]  = :present
    @property_hash[:charset] = @resource[:charset]
    @property_hash[:collate] = @resource[:collate]

    exists? ? (return true) : (return false)
  end

  def destroy
    self.class.mysql_caller("drop database if exists `#{@resource[:name]}`", 'regular')

    @property_hash.clear
    exists? ? (return false) : (return true)
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  mk_resource_methods

  def charset=(value)
    self.class.mysql_caller("alter database `#{resource[:name]}` CHARACTER SET #{value}", 'regular')
    @property_hash[:charset] = value
    (charset == value) ? (return true) : (return false)
  end

  def collate=(value)
    self.class.mysql_caller("alter database `#{resource[:name]}` COLLATE #{value}", 'regular')
    @property_hash[:collate] = value
    (collate == value) ? (return true) : (return false)
  end
end
