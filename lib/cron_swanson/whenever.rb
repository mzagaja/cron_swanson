module CronSwanson
  # integration for the whenever gem: https://github.com/javan/whenever
  class Whenever
    # CronSwanson integration for whenever
    #
    # The given block can use any job types understood by your whenever configuration.
    # See https://github.com/javan/whenever#define-your-own-job-types.
    #
    # CronSwanson currently uses the location it is invoked from in schedule.rb
    # to calculate a job time. This means that moving the `.add` invocation to
    # a different line in schedule.rb will cause it to be run at a different time.
    #
    # This limitation exists because I (currently) don't know of a way to inspect
    # the contents of a block at runtime. If a way to do this can be found, I
    # would prefer to calculate the time based on the block's contents.
    #
    # @example run a job once/day
    #   # in the config/schedule.rb file
    #   CronSwanson::Whenever.add(self) do
    #     rake 'job'
    #   end
    #
    # @example run a job four times daily
    #   # in the config/schedule.rb file
    #
    #   # with ActiveSupport
    #   CronSwanson::Whenever.add(self, interval: 4.hours) do
    #     rake 'job'
    #   end
    #
    #   # without ActiveSupport
    #   CronSwanson::Whenever.add(self, interval: 60 * 60 * 4) do
    #     rake 'job'
    #   end
    #
    # @param [Whenever::JobList] whenever_job_list For code in `config/schedule.rb`
    #   this can be referred to as `self`.
    # @param [Integer] interval how many seconds do you want between runs of this job
    def self.add(whenever_job_list, interval: CronSwanson.default_interval, &block)
      @whenever_jobs = []
      @whenever_job_list = whenever_job_list

      if !whenever_job_list.is_a?(::Whenever::JobList)
        raise ArgumentError, "supply a Whenever::JobList. (In schedule.rb code, use `self`.)"
      end

      raise ArgumentError, "provide a block containing jobs to schedule." if !block_given?

      # execute the block in the context of CronSwanson::Whenever (rather than the Whenever::JobList)
      # so that we can intercept calls to `rake` and similar (via .method_missing below).
      instance_eval(&block)

      # make a schedule based on the contents of the jobs which were defined in the block
      schedule_seed = @whenever_jobs.map do |job_config|
        m, args, _block = *job_config
        "#{m} #{args.join}"
      end
      schedule = CronSwanson.schedule(schedule_seed, interval: interval)

      # now that we know when to schedule the jobs, actually pass the block to Whenever
      whenever_job_list.every(schedule, &Proc.new)

      @whenever_job_list = nil
    end

    # during .add, we accumulate calls to whenever job types
    # this allows us to make a schedule hash from the actual jobs which are defined.
    def self.method_missing(m, *args, &block)
      raise "method_missing invoked outside of .add" if !@whenever_job_list

      if @whenever_job_list.respond_to?(m)
        @whenever_jobs << [m, args, block]
      else
        raise "#{m} is not defined. Call `job_type` to resolve this."
      end
    end
  end
end
