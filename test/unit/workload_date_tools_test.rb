# -*- encoding : utf-8 -*-
require File.expand_path('../../test_helper', __FILE__)

class WorkloadDateToolsTest < WorkloadTestCase

  test "getWorkingDaysInTimespan works if start and end day are equal and no holiday." do

    date = Date.new(2005, 12, 30);      # A friday
    assert_equal Set::new([date]), RedmineWorkload::DateTools.getWorkingDaysInTimespan(date..date, true);
  end

  test "getWorkingDaysInTimespan works if start and end day are equal and a holiday." do

    # Set friday to be a holiday.
    with_settings 'non_working_week_days' => ['5', '6', '7'] do

      date = Date.new(2005, 12, 30);      # A friday
      assert_equal Set::new, RedmineWorkload::DateTools.getWorkingDaysInTimespan(date..date, true);
    end
  end

  test "getWorkingDaysInTimespan works if start day before end day." do

    startDate = Date.new(2005, 12, 30); # A friday
    endDate = Date.new(2005, 12, 28);   # A wednesday
    assert_equal Set::new, RedmineWorkload::DateTools.getWorkingDaysInTimespan(startDate..endDate, true);
  end

  test "getWorkingDaysInTimespan works if both days follow each other and are holidays." do

    # Set wednesday and thursday to be a holiday.
    with_settings 'non_working_week_days' => ['3', '4', '6', '7'] do

      startDate = Date.new(2005, 12, 28); # A wednesday
      endDate = Date.new(2005, 12, 29);     # A thursday
      assert_equal Set::new, RedmineWorkload::DateTools.getWorkingDaysInTimespan(startDate..endDate, true);
    end
  end

  test "getWorkingDaysInTimespan works if only weekends and mondays are holidays and startday is thursday, endday is tuesday." do

    with_settings 'non_working_week_days' => ['1', '6', '7'] do

      startDate = Date.new(2005, 12, 29); # A thursday
      endDate = Date.new(2006, 1, 3);     # A tuesday

      expectedResult = [
        startDate,
        Date::new(2005, 12, 30),
        endDate
      ]

      assert_equal Set::new(expectedResult), RedmineWorkload::DateTools.getWorkingDaysInTimespan(startDate..endDate, true);
    end
  end

  test "getWorkingDays returns the working days." do
    with_settings 'non_working_week_days' => ['1', '6', '7'] do
      assert_equal Set.new([2, 3, 4, 5]), RedmineWorkload::DateTools.getWorkingDays()
    end
  end

end
