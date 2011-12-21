#
# Copyright 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

class SystemTask < ActiveRecord::Base
  belongs_to :system
  belongs_to :task_status


  TYPES = {
      #package tasks
     :package_install => {
          :name => _("Package Install"),
          :type => :package,
          :event_messages => {
              :running => [N_('installing package...'),N_('installing packages...')],
              :waiting => [N_('installing package...'),N_('installing packages...')],
              :finished => [N_('%s package installed'), N_('%s (%s other packages) installed.')],
              :error=> [N_('%s package install failed'), N_('%s (%s other packages) install failed')],
              :cancelled => [N_('%s package install cancelled'), N_('%s (%s other packages) install cancelled')],
              :timed_out =>[N_('%s package install timed out'), N_('%s (%s other packages) install timed out')],
          },
         :user_message => _('Package Install scheduled by %s')

      },
      :package_update => {
          :name => _("Package Update"),
          :type => :package,
          :event_messages => {
              :running => [N_('updating package...'), N_('updating packages...')],
              :waiting => [N_('updating package...'), N_('updating packages...')],
              :finished =>[ N_('%s package updated'), N_('%s (%s other packages) updated')],
              :error => [N_('%s package update failed'), N_('%s (%s other packages) update failed')],
              :cancelled =>[N_('%s package update cancelled'), N_('%s (%s other packages) update cancelled')],
              :timed_out =>[N_('%s package update timed out'), N_('%s (%s other packages) update timed out')],
          },
          :user_message => _('Package Update scheduled by %s')
      },
      :package_remove => {
          :name => _("Package Remove"),
          :type => :package,
          :event_messages => {
              :running => [N_('removing package...'), N_('removing packages...')],
              :waiting => [N_('removing package...'), N_('removing packages...')],
              :finished => [N_('%s package removed'), N_('%s (%s other packages) removed')],
              :error => [N_('%s package remove failed'), N_('%s (%s other packages) remove failed')],
              :cancelled => [N_('%s package remove cancelled'), N_('%s (%s other packages) remove cancelled')],
              :timed_out => [N_('%s package remove timed out'), N_('%s (%s other packages) remove timed out')],
          },
          :user_message => _('Package Remove scheduled by %s')
      },
      #package group tasks
      :package_group_install => {
          :name => _("Package Group Install"),
          :type => :package_group,
          :event_messages => {
              :running => [N_('installing package group...'),N_('installing package groups...')],
              :waiting => [N_('installing package group...'),N_('installing package groups...')],
              :finished => [N_('%s package group installed'), N_('%s (%s other package groups) installed.')],
              :error=> [N_('%s package group install failed'), N_('%s (%s other package groups) install failed')],
              :cancelled => [N_('%s package group install cancelled'), N_('%s (%s other package groups) install cancelled')],
              :timed_out =>[N_('%s package group install timed out'), N_('%s (%s other package groups) install timed out')],
          },
          :user_message => _('Package Group Install scheduled by %s')
      },
      :package_group_update => {
          :name => _("Package Group Update"),
          :type => :package_group,
          :event_messages => {
              :running => [N_('updating package group...'), N_('updating package groups...')],
              :waiting => [N_('updating package group...'), N_('updating package groups...')],
              :finished =>[ N_('%s package group updated'), N_('%s (%s other package groups) updated')],
              :error => [N_('%s package group update failed'), N_('%s (%s other package groups) update failed')],
              :cancelled =>[N_('%s package group update cancelled'), N_('%s (%s other package groups) update cancelled')],
              :timed_out =>[N_('%s package group update timed out'), N_('%s (%s other package groups) update timed out')],

          },
          :user_message => _('Package Group Update scheduled by %s')
      },
      :package_group_remove => {
          :name => _("Package Group Remove"),
          :type => :package_group,
          :event_messages => {
              :running => [N_('removing package group...'), N_('removing package groups...')],
              :waiting => [N_('removing package group...'), N_('removing package groups...')],
              :finished => [N_('%s package group removed'), N_('%s (%s other package groups) removed')],
              :error => [N_('%s package group remove failed'), N_('%s (%s other package groups) remove failed')],
              :cancelled => [N_('%s package group remove cancelled'), N_('%s (%s other package groups) remove cancelled')],
              :timed_out => [N_('%s package group remove timed out'), N_('%s (%s other package groups) remove timed out')],

          },
          :user_message => _('Package Group Remove scheduled by %s')
      },

  }.with_indifferent_access

  class << self
    def pending_message_for task
      details = SystemTask::TYPES[task.task_type]
      case details[:type]
        when :package
          p = task.parameters[:packages]
          unless p && p.length > 0
            if "package_update" == task.task_type
              return _("all packages")
            end
            return ""
          end
          return n_("%s", N_("%s (%s other packages)"), p.length) % [p.first, p.length - 1]
      end

    end
    def message_for task
      details = SystemTask::TYPES[task.task_type]
      case details[:type]
        when :package
          p = task.parameters[:packages]
          unless p && p.length > 0
            if "package_update" == task.task_type
              case task.state
                when "running"
                  return "updating"
                when "waiting"
                  return "updating"
                when "error"
                  return _("all packages update failed")
                else
                  return _("all packages updated")
              end
            end
            return ""
          end
          msg = details[:event_messages][task.state]
          r = msg + [p.length]
          return n_(*r) % [p.first, p.length - 1]
        else
          return "Boo yeah"
      end
    end

    def refresh(ids)
      ids.each do |id|
        TaskStatus.find(id).refresh_pulp
      end
    end

    def refresh_for_system(sid)
      query = SystemTask.select(:task_status_id).joins(:task_status).where(:system_id => sid)
      ids = query.where("task_statuses.state"=>[:waiting, :running]).collect {|row| row[:task_status_id]}
      refresh(ids)
      TaskStatus.where("task_statuses.id in (#{query.to_sql})")
    end

    def make system, pulp_task, task_type, parameters
      task_status = PulpTaskStatus.using_pulp_task(pulp_task) do |t|
         t.organization = system.organization
         t.task_type = task_type
         t.parameters = parameters
      end
      task_status.save!
      system_task = SystemTask.create!(:system => system, :task_status => task_status)
      system_task
    end
  end

  # non self methods
  def humanize_type
    { :package_install => _("Package Install"),
      :package_update =>  _("Package Update"),
      :package_remove => _("Package Remove"),
      :package_group_install => _("Package Group Install"),
      :package_group_update => _("Package Group Update"),
      :package_group_remove => _("Package Group Remove"),
    }[task_status.task_type.to_sym].to_s
  end

  def humanize_parameters
    humanized_parameters = []
    parameters = task_status.parameters
    if packages = parameters[:packages]
      humanized_parameters.concat(packages)
    end
    if groups = parameters[:groups]
      humanized_parameters.concat(groups.map {|g| "@#{g}"})
    end
    humanized_parameters.join(", ")
  end

  def description
    ret = ""
    ret << humanize_type << ": "
    ret << humanize_parameters
  end

  def result_description
    case task_status.state.to_s
    when "finished"
      success_description
    when "error"
      error_description
    else ""
    end
  end

  def success_description
    ret = ""
    task_type = task_status.task_type.to_s
    result = task_status.result
    if task_type =~ /^package_group/
      action = task_type.include?("remove") ? :removed : :installed
      if result.empty?
        ret << packages_change_description([], action)
      else
        result.each do |(group, packages)|
          ret << "@#{group}\n"
          ret << packages_change_description(packages, action)
          ret << "\n"
        end
      end
    elsif task_status.task_type.to_s == "package_remove"
      ret << packages_change_description(result, :removed)
    else
      if result[:installed]
        ret << packages_change_description(result[:installed], :installed)
      end
      if result[:updated]
        ret << packages_change_description(result[:updated], :updated)
      end
    end
    ret
  end

  def packages_change_description(packages, action)
    ret = ""
    if packages.empty?
      case action
      when :updated
        ret << _("No packages updated")
      when :removed
        ret << _("No packages removed")
      else
        ret << _("No new packages installed")
      end
    else
      if action == :updated
          ret << packages.map do |(new_version, details)|
            detail = new_version
            unless details[:updates].blank?
              detail += " " + _("updated") + " " + details[:updates].join("\n")
            end
            unless details[:obsoletes].blank?
              detail += " " + _("obsoleted") + " " + details[:obsoletes].join("\n")
            end
            detail
          end.join(" \n")
      else
      verb = case action
             when :removed then _("removed")
             else _("installed")
             end
      ret << packages.map{|i| "#{i} #{verb}"}.join("\n")
      end
    end
    ret
  end

  def error_description
    errors, stacktrace = task_status.result[:errors]
    return "" unless errors

    # Handle not very friendly Pulp message
    if errors =~ /^\(.*\)$/
      stacktrace.last.split(":").first
    elsif errors =~ /^\[.*,.*\]$/m
      errors.split(",").map do |error|
        error.gsub(/^\W+|\W+$/,"")
      end.join("\n")
    else
      errors
    end
  end

  def as_json(*args)
    methods = [:description, :result_description]
    ret = self.task_status.as_json(:except => task_status.as_json(:except => :id))
    ret.merge!(super(:only => methods, :methods => methods))
    ret[:system_name] = system.name
    ret
  end

end
