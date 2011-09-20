class SimpleJob
  def self.perform
  end
end

class CustomQueue
  @queue = :custom
end

shared_examples_for 'a backend' do
  before(:all) do
    Qu.backend = described_class.new
  end

  before do
    subject.clear
  end

  describe 'enqueue' do
    it 'should return a job id' do
      subject.enqueue(SimpleJob).should be_instance_of(Qu::Job)
    end

    it 'should add a job to the queue' do
      job = subject.enqueue(SimpleJob)
      job.queue.should == 'default'
      subject.length(job.queue).should == 1
    end

    it 'should add queue to list of queues' do
      subject.queues.should == []
      job = subject.enqueue(SimpleJob)
      subject.queues.should == [job.queue]
    end

    it 'should assign a different job id for the same job enqueue multiple times' do
      subject.enqueue(SimpleJob).id.should_not == subject.enqueue(SimpleJob).id
    end
  end

  describe 'clear' do
    it 'should clear jobs for given queue' do
      job = subject.enqueue SimpleJob
      subject.length(job.queue).should == 1
      subject.clear(job.queue)
      subject.length(job.queue).should == 0
      subject.queues.should_not include(job.queue)
    end

    it 'should not clear jobs for a different queue' do
      job = subject.enqueue SimpleJob
      subject.clear('other')
      subject.length(job.queue).should == 1
    end

    it 'should clear all queues without any args' do
      subject.enqueue(SimpleJob).queue.should == 'default'
      subject.enqueue(CustomQueue).queue.should == 'custom'
      subject.length('default').should == 1
      subject.length('custom').should == 1
      subject.clear
      subject.length('default').should == 0
      subject.length('custom').should == 0
    end
  end

  describe 'reserve' do
    let(:worker) { Qu::Worker.new('default') }

    before do
      @job = subject.enqueue SimpleJob
    end

    it 'should return next job' do
      subject.reserve(worker).id.should == @job.id
    end

    it 'should not return an already reserved job' do
      another_job = subject.enqueue SimpleJob
      subject.reserve(worker).id.should_not == subject.reserve(worker).id
    end

    it 'should return next job in given queues' do
      subject.enqueue SimpleJob
      job = subject.enqueue CustomQueue
      subject.enqueue SimpleJob

      worker = Qu::Worker.new('custom', 'default')

      subject.reserve(worker).id.should == job.id
    end

    it 'should not return job from different queue' do
      worker = Qu::Worker.new('video')
      timeout { subject.reserve(worker) }.should be_nil
    end

    it 'should block by default if no jobs available' do
      subject.clear
      timeout(1) do
        subject.reserve(worker)
        fail("#reserve should block")
      end
    end

    it 'should not block if :block option is set to false' do
      timeout(1) do
        subject.reserve(worker, :block => false)
        true
      end.should be_true
    end

    def timeout(count = 0.1, &block)
      SystemTimer.timeout(count, &block)
    rescue Timeout::Error
      nil
    end
  end
end
