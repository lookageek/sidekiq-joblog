require 'set'

module Sidekiq
  module Middleware
    module Server
      class JobLog
        def initialize(model:, application:, except: [])
          @model         = model
          @application   = application
          @excluded_jobs = Set.new(except)
        end

        def call(worker, msg, queue)
          if @excluded_jobs.include?(worker.class)
            yield
            return
          end

          start_time = Time.now.to_f

          data = {
            job_klass: worker.class.name,
            jid: msg['jid'],
            queue: queue,
            event: 'start',
            queued_at: msg['created_at'],
            waited: start_time - msg['created_at']
          }
          save(data)

          begin
            yield
            data[:event] = 'finish'
          rescue => e
            data[:event] = 'error'
            data[:error] = e.class.name
          end

          end_time = Time.now.to_f
          data[:worked] = end_time - start_time
          data[:total]  = end_time - msg['created_at']
          save(data)

          raise e if e
        end

        private

        def save(data)
          @model.create(data) rescue nil
        end
      end
    end
  end
end
