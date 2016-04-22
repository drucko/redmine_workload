# -*- encoding : utf-8 -*-
require File.expand_path('../../test_helper', __FILE__)

class WorkloadListUserTest < WorkloadTestCase

  fixtures :trackers, :projects, :projects_trackers, :members, :member_roles,
           :users, :issue_statuses, :enumerations, :roles, :enabled_modules


  test "getOpenIssuesForUsers returns empty list if no users given" do
    user = User.generate!
    issue = Issue.generate!(:assigned_to => user,
                             :status => IssueStatus.find(1) # New, not closed
                           )

    assert_equal [], RedmineWorkload::ListUser.getOpenIssuesForUsers([])
  end

  test "getOpenIssuesForUsers returns only issues of interesting users" do
    user1 = User.generate!
    user2 = User.generate!

    issue1 = Issue.generate!(:assigned_to => user1,
                             :status => IssueStatus.find(1) # New, not closed
                            )

    issue2 = Issue.generate!(:assigned_to => user2,
                             :status => IssueStatus.find(1) # New, not closed
                            )

    assert_equal [issue2], RedmineWorkload::ListUser.getOpenIssuesForUsers([user2])
  end

  test "getOpenIssuesForUsers returns only open issues" do
    user = User.generate!

    issue1 = Issue.generate!(:assigned_to => user,
                             :status => IssueStatus.find(1) # New, not closed
                            )

    issue2 = Issue.generate!(:assigned_to => user,
                             :status => IssueStatus.find(6) # Rejected, closed
                            )

    assert_equal [issue1], RedmineWorkload::ListUser.getOpenIssuesForUsers([user])
  end

  test "getMonthsBetween returns [] if last day after first day" do
    firstDay = Date::new(2012, 3, 29)
    lastDay = Date::new(2012, 3, 28)

    assert_equal [], RedmineWorkload::ListUser.getMonthsInTimespan(firstDay..lastDay).map{|hsh| hsh[:first_day].month}
  end

  test "getMonthsBetween returns [3] if both days in march 2012 and equal" do
    firstDay = Date::new(2012, 3, 27)
    lastDay = Date::new(2012, 3, 27)

    assert_equal [3], RedmineWorkload::ListUser.getMonthsInTimespan(firstDay..lastDay).map{|hsh| hsh[:first_day].month}
  end

  test "getMonthsBetween returns [3] if both days in march 2012 and different" do
    firstDay = Date::new(2012, 3, 27)
    lastDay = Date::new(2012, 3, 28)

    assert_equal [3], RedmineWorkload::ListUser.getMonthsInTimespan(firstDay..lastDay).map{|hsh| hsh[:first_day].month}
  end

  test "getMonthsBetween returns [3, 4, 5] if first day in march and last day in may" do
    firstDay = Date::new(2012, 3, 31)
    lastDay = Date::new(2012, 5, 1)

    assert_equal [3, 4, 5], RedmineWorkload::ListUser.getMonthsInTimespan(firstDay..lastDay).map{|hsh| hsh[:first_day].month}
  end

  test "getMonthsBetween returns correct result timespan overlaps year boundary" do
    firstDay = Date::new(2011, 3, 3)
    lastDay = Date::new(2012, 5, 1)

    assert_equal (3..12).to_a.concat((1..5).to_a), RedmineWorkload::ListUser.getMonthsInTimespan(firstDay..lastDay).map{|hsh| hsh[:first_day].month}
  end

  def assertIssueTimesHashEquals(expected, actual)

    assert expected.is_a?(Hash), "Expected is no hash."
    assert actual.is_a?(Hash),   "Actual is no hash."

    assert_equal expected.keys.sort, actual.keys.sort, "Date keys are not equal"

    expected.keys.sort.each do |day|

      assert expected[day].is_a?(Hash), "Expected is no hashon day #{day.to_s}."
      assert actual[day].is_a?(Hash),   "Actual is no hash on day #{day.to_s}."

      assert expected[day].has_key?(:hours),      "On day #{day.to_s}, expected has no key :hours"
      assert expected[day].has_key?(:active),     "On day #{day.to_s}, expected has no key :active"
      assert expected[day].has_key?(:noEstimate), "On day #{day.to_s}, expected has no key :noEstimate"
      assert expected[day].has_key?(:holiday),    "On day #{day.to_s}, expected has no key :holiday"

      assert actual[day].has_key?(:hours),        "On day #{day.to_s}, actual has no key :hours"
      assert actual[day].has_key?(:active),       "On day #{day.to_s}, actual has no key :active"
      assert actual[day].has_key?(:noEstimate),   "On day #{day.to_s}, actual has no key :noEstimate"
      assert actual[day].has_key?(:holiday),      "On day #{day.to_s}, actual has no key :holiday"

      assert_in_delta expected[day][:hours],   actual[day][:hours], 1e-4, "On day #{day.to_s}, hours wrong"
      assert_equal expected[day][:active],     actual[day][:active],      "On day #{day.to_s}, active wrong"
      assert_equal expected[day][:noEstimate], actual[day][:noEstimate],  "On day #{day.to_s}, noEstimate wrong"
      assert_equal expected[day][:holiday],    actual[day][:holiday],     "On day #{day.to_s}, holiday wrong"
    end
  end

  test "getHoursForIssuesPerDay returns {} if time span empty" do

    issue = Issue.generate!(
                             :start_date => Date::new(2013, 5, 31),
                             :due_date => Date::new(2013, 6, 2),
                             :estimated_hours => 10.0,
                             :done_ratio => 10
                           )

    firstDay = Date::new(2013, 5, 31)
    lastDay = Date::new(2013, 5, 29)

    assertIssueTimesHashEquals Hash::new, RedmineWorkload::ListUser.getHoursForIssuesPerDay(issue, firstDay..lastDay, firstDay)
  end

  test "getHoursForIssuesPerDay works if issue is completely in given time span and nothing done" do

    with_wednesday_as_holiday do

      issue = Issue.generate!(
                               :start_date => Date::new(2013, 5, 31), # A Friday
                               :due_date => Date::new(2013, 6, 2),    # A Sunday
                               :estimated_hours => 10.0,
                               :done_ratio => 0
                             )

      firstDay = Date::new(2013, 5, 31) # A Friday
      lastDay = Date::new(2013, 6, 3)   # A Monday

      expectedResult = {
        Date::new(2013, 5, 31) => {
          :hours => 10.0,
          :active => true,
          :noEstimate => false,
          :holiday => false
        },
        Date::new(2013, 6, 1) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => true
        },
        Date::new(2013, 6, 2) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => true
        },
        Date::new(2013, 6, 3) => {
          :hours => 0.0,
          :active => false,
          :noEstimate => false,
          :holiday => false
        }
      }

      assertIssueTimesHashEquals expectedResult, RedmineWorkload::ListUser.getHoursForIssuesPerDay(issue, firstDay..lastDay, firstDay)

    end
  end

  test "getHoursForIssuesPerDay works if issue lasts after time span and done_ratio > 0" do

    with_wednesday_as_holiday do

      # 30 hours still need to be done, 3 working days until issue is finished.
      issue = Issue.generate!(
                               :start_date => Date::new(2013, 5, 28), # A Tuesday
                               :due_date => Date::new(2013, 6, 1),    # A Saturday
                               :estimated_hours => 40.0,
                               :done_ratio => 25
                             )

      firstDay = Date::new(2013, 5, 27) # A Monday, before issue starts
      lastDay = Date::new(2013, 5, 30)   # Thursday, before issue ends

      expectedResult = {
        # Monday, no holiday, before issue starts.
        Date::new(2013, 5, 27) => {
          :hours => 0.0,
          :active => false,
          :noEstimate => false,
          :holiday => false
        },
        # Tuesday, no holiday, issue starts here
        Date::new(2013, 5, 28) => {
          :hours => 10.0,
          :active => true,
          :noEstimate => false,
          :holiday => false
        },
        # Wednesday, holiday
        Date::new(2013, 5, 29) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => true
        },
        # Thursday, no holiday, last day of time span
        Date::new(2013, 5, 30) => {
          :hours => 10.0,
          :active => true,
          :noEstimate => false,
          :holiday => false
        }
      }

      assertIssueTimesHashEquals expectedResult, RedmineWorkload::ListUser.getHoursForIssuesPerDay(issue, firstDay..lastDay, firstDay)
    end
  end

  test "getHoursForIssuesPerDay works if issue starts before time span" do

    with_wednesday_as_holiday do

      # 36 hours still need to be done, 2 working days until issue is due.
      # One day has already passed with 10% done.
      issue = Issue.generate!(
                               :start_date => Date::new(2013, 5, 28), # A Thursday
                               :due_date => Date::new(2013, 6, 1),    # A Saturday
                               :estimated_hours => 40.0,
                               :done_ratio => 10
                             )

      firstDay = Date::new(2013, 5, 29) # A Wednesday, before issue starts
      lastDay = Date::new(2013, 6, 1)   # Saturday, before issue ends

      expectedResult = {
        # Wednesday, holiday, first day of time span.
        Date::new(2013, 5, 29) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => true
        },
        # Thursday, no holiday
        Date::new(2013, 5, 30) => {
          :hours => 18.0,
          :active => true,
          :noEstimate => false,
          :holiday => false
        },
        # Friday, no holiday
        Date::new(2013, 5, 31) => {
          :hours => 18.0,
          :active => true,
          :noEstimate => false,
          :holiday => false
        },
        # Saturday, holiday, last day of time span
        Date::new(2013, 6, 1) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => true
        }
      }

      assertIssueTimesHashEquals expectedResult, RedmineWorkload::ListUser.getHoursForIssuesPerDay(issue, firstDay..lastDay, firstDay)
    end
  end

  test "getHoursForIssuesPerDay works if issue completely before time span" do

    with_wednesday_as_holiday do

      # 10 hours still need to be done, but issue is overdue. Remaining hours need
      # to be put on first working day of time span.
      issue = Issue.generate!(
                               :start_date => nil,                 # No start date
                               :due_date => Date::new(2013, 6, 1), # A Saturday
                               :estimated_hours => 100.0,
                               :done_ratio => 90
                             )

      firstDay = Date::new(2013, 6, 2)  # Sunday, after issue due date
      lastDay = Date::new(2013, 6, 4)   # Tuesday

      expectedResult = {
        # Sunday, holiday.
        Date::new(2013, 6, 2) => {
          :hours => 0.0,
          :active => false,
          :noEstimate => false,
          :holiday => true
        },
        # Monday, no holiday, first working day in time span.
        Date::new(2013, 6, 3) => {
          :hours => 10.0,
          :active => false,
          :noEstimate => false,
          :holiday => false
        },
        # Tuesday, no holiday
        Date::new(2013, 6, 4) => {
          :hours => 0.0,
          :active => false,
          :noEstimate => false,
          :holiday => false
        }
      }

      assertIssueTimesHashEquals expectedResult, RedmineWorkload::ListUser.getHoursForIssuesPerDay(issue, firstDay..lastDay, firstDay)
    end
  end

  test "getHoursForIssuesPerDay works if issue has no due date" do

    with_wednesday_as_holiday do

      # 10 hours still need to be done.
      issue = Issue.generate!(
                               :start_date => Date::new(2013, 6, 3), # A Tuesday
                               :due_date => nil,
                               :estimated_hours => 100.0,
                               :done_ratio => 90
                             )

      firstDay = Date::new(2013, 6, 2)  # Sunday
      lastDay = Date::new(2013, 6, 4)   # Tuesday

      expectedResult = {
        # Sunday, holiday.
        Date::new(2013, 6, 2) => {
          :hours => 0.0,
          :active => false,
          :noEstimate => false,
          :holiday => true
        },
        # Monday, no holiday, first working day in time span.
        Date::new(2013, 6, 3) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => true,
          :holiday => false
        },
        # Tuesday, no holiday
        Date::new(2013, 6, 4) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => true,
          :holiday => false
        }
      }

      assertIssueTimesHashEquals expectedResult, RedmineWorkload::ListUser.getHoursForIssuesPerDay(issue, firstDay..lastDay, firstDay)
    end
  end

  test "getHoursForIssuesPerDay works if issue has no start date" do

    with_wednesday_as_holiday do

      # 10 hours still need to be done.
      issue = Issue.generate!(
                               :start_date => nil,
                               :due_date => Date::new(2013, 6, 3),
                               :estimated_hours => 100.0,
                               :done_ratio => 90
                             )

      firstDay = Date::new(2013, 6, 2)  # Sunday
      lastDay = Date::new(2013, 6, 4)   # Tuesday

      expectedResult = {
        # Sunday, holiday.
        Date::new(2013, 6, 2) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => true
        },
        # Monday, no holiday, first working day in time span.
        Date::new(2013, 6, 3) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => true,
          :holiday => false
        },
        # Tuesday, no holiday
        Date::new(2013, 6, 4) => {
          :hours => 0.0,
          :active => false,
          :noEstimate => false,
          :holiday => false
        }
      }

      assertIssueTimesHashEquals expectedResult, RedmineWorkload::ListUser.getHoursForIssuesPerDay(issue, firstDay..lastDay, firstDay)
    end
  end

  test "getHoursForIssuesPerDay works if in time span and issue overdue" do

    with_wednesday_as_holiday do

      # 10 hours still need to be done, but issue is overdue. Remaining hours need
      # to be put on first working day of time span.
      issue = Issue.generate!(
                               :start_date => nil,                 # No start date
                               :due_date => Date::new(2013, 6, 1), # A Saturday
                               :estimated_hours => 100.0,
                               :done_ratio => 90
                             )

      firstDay = Date::new(2013, 5, 30)  # Thursday
      lastDay = Date::new(2013, 6, 4)    # Tuesday
      today = Date::new(2013, 6, 2)      # After issue end

      expectedResult = {
        # Thursday, in the past.
        Date::new(2013, 5, 30) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => false
        },
        # Friday, in the past.
        Date::new(2013, 5, 31) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => false
        },
        # Saturday, holiday, in the past.
        Date::new(2013, 6, 1) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => true
        },
        # Sunday, holiday.
        Date::new(2013, 6, 2) => {
          :hours => 0.0,
          :active => false,
          :noEstimate => false,
          :holiday => true
        },
        # Monday, no holiday, first working day in time span.
        Date::new(2013, 6, 3) => {
          :hours => 10.0,
          :active => false,
          :noEstimate => false,
          :holiday => false
        },
        # Tuesday, no holiday
        Date::new(2013, 6, 4) => {
          :hours => 0.0,
          :active => false,
          :noEstimate => false,
          :holiday => false
        }
      }

      assertIssueTimesHashEquals expectedResult, RedmineWorkload::ListUser.getHoursForIssuesPerDay(issue, firstDay..lastDay, today)
    end
  end

  test "getHoursForIssuesPerDay works if issue is completely in given time span, but has started" do

    with_wednesday_as_holiday do

      issue = Issue.generate!(
                               :start_date => Date::new(2013, 5, 31), # A Friday
                               :due_date => Date::new(2013, 6, 4),    # A Tuesday
                               :estimated_hours => 10.0,
                               :done_ratio => 0
                             )

      firstDay = Date::new(2013, 5, 31) # A Friday
      lastDay = Date::new(2013, 6, 5)   # A Wednesday
      today = Date::new(2013, 6, 2)     # A Sunday

      expectedResult = {
        # Friday
        Date::new(2013, 5, 31) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => false
        },
        # Saturday
        Date::new(2013, 6, 1) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => true
        },
        # Sunday
        Date::new(2013, 6, 2) => {
          :hours => 0.0,
          :active => true,
          :noEstimate => false,
          :holiday => true
        },
        # Monday
        Date::new(2013, 6, 3) => {
          :hours => 5.0,
          :active => true,
          :noEstimate => false,
          :holiday => false
        },
        # Tuesday
        Date::new(2013, 6, 4) => {
          :hours => 5.0,
          :active => true,
          :noEstimate => false,
          :holiday => false
        },
        # Wednesday
        Date::new(2013, 6, 5) => {
          :hours => 0.0,
          :active => false,
          :noEstimate => false,
          :holiday => true
        }
      }

      assertIssueTimesHashEquals expectedResult, RedmineWorkload::ListUser.getHoursForIssuesPerDay(issue, firstDay..lastDay, today)
    end
  end

  test "getHoursPerUserIssueAndDay returns correct structure" do
    user = User.find(2)
    project = Project.find(1)
    User.current = user

    issue1 = Issue.generate!(
                             :assigned_to => user,
                             :project => project,
                             :start_date => Date::new(2013, 5, 31), # A Friday
                             :due_date => Date::new(2013, 6, 4),    # A Tuesday
                             :estimated_hours => 10.0,
                             :done_ratio => 50,
                             :status => IssueStatus.find(1) # New, not closed
                            )

    issue2 = Issue.generate!(
                             :assigned_to => user,
                             :project => project,
                             :start_date => Date::new(2013, 6, 3), # A Friday
                             :due_date => Date::new(2013, 6, 6),    # A Tuesday
                             :estimated_hours => 30.0,
                             :done_ratio => 50,
                             :status => IssueStatus.find(1) # New, not closed
                            )

    firstDay = Date.new(2013, 5, 25)
    lastDay = Date.new(2013, 6, 4)
    today = Date.new(2013, 5, 31)

    workloadData = RedmineWorkload::ListUser.getHoursPerUserIssueAndDay([issue1, issue2], firstDay..lastDay, today)

    assert user_data = workloadData[user]

    # Check that issue1 and 2 are the only keys for the user.
    assert_equal 5, user_data.keys.count
    assert user_data.key?(issue1.project)
    assert project_data = user_data[issue1.project]
    assert project_data.key?(issue1)
    assert project_data.key?(issue2)
  end

  test "getEstimatedTimeForIssue works for issue without children." do
    issue = Issue.generate!(:estimated_hours => 13.2)
    assert_in_delta 13.2, RedmineWorkload::ListUser.getEstimatedTimeForIssue(issue), 1e-4
  end

  test "getEstimatedTimeForIssue works for issue with children." do
    parent = Issue.generate!(:estimated_hours => 3.6)
    child1 = Issue.generate!(:estimated_hours => 5.0, :parent_issue_id => parent.id, :done_ratio => 90)
    child2 = Issue.generate!(:estimated_hours => 9.0, :parent_issue_id => parent.id)

    # Force parent to reload so the data from the children is incorporated.
    parent.reload

    assert_in_delta 0.0, RedmineWorkload::ListUser.getEstimatedTimeForIssue(parent), 1e-4
    assert_in_delta 0.5, RedmineWorkload::ListUser.getEstimatedTimeForIssue(child1), 1e-4
    assert_in_delta 9.0, RedmineWorkload::ListUser.getEstimatedTimeForIssue(child2), 1e-4
  end

  test "getEstimatedTimeForIssue works for issue with grandchildren." do
    parent = Issue.generate!(:estimated_hours => 4.5)
    child = Issue.generate!(:estimated_hours => 5.0, :parent_issue_id => parent.id)
    grandchild = Issue.generate!(:estimated_hours => 9.0, :parent_issue_id => child.id, :done_ratio => 40)

    # Force parent and child to reload so the data from the children is
    # incorporated.
    parent.reload
    child.reload

    assert_in_delta 0.0, RedmineWorkload::ListUser.getEstimatedTimeForIssue(parent), 1e-4
    assert_in_delta 0.0, RedmineWorkload::ListUser.getEstimatedTimeForIssue(child), 1e-4
    assert_in_delta 5.4, RedmineWorkload::ListUser.getEstimatedTimeForIssue(grandchild), 1e-4
  end

  test "getLoadClassForHours returns \"none\" for workloads below threshold for low workload" do
    with_load_settings 0.1, 5.0, 7.0 do
      assert_equal "none", RedmineWorkload::ListUser.getLoadClassForHours(0.05)
    end
  end

  test "getLoadClassForHours returns \"low\" for workloads between thresholds for low and normal workload" do
    with_load_settings 0.1, 5.0, 7.0 do
      assert_equal "low", RedmineWorkload::ListUser.getLoadClassForHours(3.5)
    end
  end

  test "getLoadClassForHours returns \"normal\" for workloads between thresholds for normal and high workload" do
    with_load_settings 0.1, 2.0, 7.0 do
      assert_equal "normal", RedmineWorkload::ListUser.getLoadClassForHours(3.5)

    end
  end

  test "getLoadClassForHours returns \"high\" for workloads above threshold for high workload" do
    with_load_settings 0.1, 2.0, 10.0 do
      assert_equal "high", RedmineWorkload::ListUser.getLoadClassForHours(10.5)
    end
  end

  test "getUsersAllowedToDisplay returns an empty array if the current user is anonymus." do
    User.current = User.anonymous

    assert_equal [], RedmineWorkload::ListUser.getUsersAllowedToDisplay
  end

  test "getUsersAllowedToDisplay returns only the user himself if user has no role assigned." do
    User.current = User.generate!

    assert_equal [User.current].map(&:id).sort, RedmineWorkload::ListUser.getUsersAllowedToDisplay.map(&:id).sort
  end

  test "getUsersAllowedToDisplay returns all users if the current user is a admin." do
    User.current = User.generate!
    # Make this user an admin (can't do it in the attributes?!?)
    User.current.admin = true

    assert_equal User.active.map(&:id).sort, RedmineWorkload::ListUser.getUsersAllowedToDisplay.map(&:id).sort
  end

  test "getUsersAllowedToDisplay returns exactly project members if user has right to see workload of project members." do
    User.current = User.generate!
    project = Project.generate!

    projectManagerRole = Role.generate!(:name => 'Project manager',
                                        :permissions => [:view_project_workload])

    User.add_to_project(User.current, project, [projectManagerRole]);

    projectMember1 = User.generate!
    User.add_to_project(projectMember1, project)
    projectMember2 = User.generate!
    User.add_to_project(projectMember2, project)

    # Create some non-member
    User.generate!

    assert_equal [User.current, projectMember1, projectMember2].map(&:id).sort, RedmineWorkload::ListUser.getUsersAllowedToDisplay.map(&:id).sort
  end



  def with_load_settings(low, normal, high, &block)
    with_plugin_settings(
      {
        'threshold_lowload_min' => low,
        'threshold_normalload_min' => normal,
        'threshold_highload_min' => high,
      }, &block
    )
  end

  # Set Saturday, Sunday and Wednesday to be a holiday, all others to be a
  # working day.
  def with_wednesday_as_holiday(&block)
    with_settings('non_working_week_days' => ['3', '6', '7'], &block)
  end

end
