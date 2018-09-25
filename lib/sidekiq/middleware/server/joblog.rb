require 'set'

module Sidekiq
  module Middleware
    module Server
      class JobLog
        def initialize(model:, app: '', except: [])
          @model         = model
          @app           = app
          @excluded_jobs = Set.new(except)
        end

        def call(worker, msg, queue)
          if @excluded_jobs.include?(worker.class)
            yield
            return
          end

          start_time = current_time_millis
          queued_at  = get_millis(msg['created_at'])

          data = {
            job_class: worker.class.name,
            app: @app,
            job_id: msg['jid'],
            queue: queue,
            event: 'start',
            queued_at: queued_at,
            waited: start_time - queued_at
          }
          save(data)

          begin
            yield
            data[:event] = 'finish'
          rescue => e
            data[:event] = 'error'
            data[:error] = e.class.name
          end

          end_time = current_time_millis
          data[:worked] = end_time - start_time
          data[:total]  = end_time - queued_at
          save(data)

          raise e if e
        end

        private

        def save(data)
          @model.create(data) rescue nil
        end

        def current_time_millis
          get_millis(Time.now.to_f)
        end

        def get_millis(float_time)
          (float_time.round(3) * 1000).to_i
        end
      end
    end
  end
end
