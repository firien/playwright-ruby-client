require 'spec_helper'

RSpec.describe 'FrameLocator' do
  shared_context route: :iframe do
    before {
      sinatra.get('/empty.html') { '<iframe src="iframe.html"></iframe>' }
      sinatra.get('/iframe.html') {
        <<~HTML
        <html>
          <div>
            <button>Hello iframe</button>
            <iframe src="iframe-2.html"></iframe>
          </div>
          <span>1</span>
          <span>2</span>
        </html>
        HTML
      }
      sinatra.get('/iframe-2.html') { '<html><button>Hello nested iframe</button></html>' }
    }
  end

  shared_context route: :ambiguous do
    before {
      sinatra.get('/empty.html') do
        <<~HTML
        <iframe src="iframe-1.html"></iframe>
        <iframe src="iframe-2.html"></iframe>
        <iframe src="iframe-3.html"></iframe>
        HTML
      end
      sinatra.get('/iframe-*.html') do |num|
        "<html><button>Hello from iframe-#{num}</button></html>"
      end
    }
  end

  it 'should work for iframe', sinatra: true, route: :iframe do
    with_page do |page|
      page.goto(server_empty_page)
      button = page.frame_locator('iframe').locator('button')
      button.wait_for
      expect(button.inner_text).to eq('Hello iframe')
      button.click
    end
  end

  it 'should work for nested iframe', sinatra: true, route: :iframe do
    with_page do |page|
      page.goto(server_empty_page)
      button = page.frame_locator('iframe').frame_locator('iframe').locator('button')
      button.wait_for
      expect(button.inner_text).to eq('Hello nested iframe')
      button.click
    end
  end

  it 'should work for $ and $$', sinatra: true, route: :iframe do
    with_page do |page|
      page.goto(server_empty_page)
      locator = page.frame_locator('iframe').locator('button')
      expect(locator.inner_text).to eq('Hello iframe')
      spans = page.frame_locator('iframe').locator('span')
      expect(spans.count).to eq(2)
    end
  end

  it 'should wait for frame', sinatra: true do
    with_page do |page|
      page.goto(server_empty_page)
      expect {
        page.frame_locator('iframe').locator('span').click(timeout: 300)
      }.to raise_error(/waiting for frame "iframe"/)
    end
  end

  it 'should wait for frame 2', sinatra: true, route: :iframe do
    with_page do |page|
      Concurrent::Promises.schedule(0.3) {
        page.goto(server_empty_page)
      }
      Timeout.timeout(2) {
        page.frame_locator('iframe').locator('button').click
      }
    end
  end

  it 'should wait for frame to go', sinatra: true, route: :iframe do
    pending 'Not work also in JS...'
    with_page do |page|
      page.goto(server_empty_page)
      Concurrent::Promises.schedule(0.3) {
        page.eval_on_selector('iframe', 'e => e.remove()')
      }
      Timeout.timeout(2) {
        page.frame_locator('iframe').locator('button').wait_for(state: :hidden)
      }
    end
  end

  it 'should not wait for frame', sinatra: true do
    pending 'Not work also in JS...'
    with_page do |page|
      page.goto(server_empty_page)
      Timeout.timeout(2) {
        page.frame_locator('iframe').locator('span').wait_for(state: :hidden)
      }
    end
  end

  it 'should not wait for frame 3', sinatra: true do
    pending 'Not work also in JS...'
    with_page do |page|
      page.goto(server_empty_page)
      puts page.eval_on_selector_all('iframe >> control=enter-frame >> span', 'el => el.length')
      expect(page.frame_locator('iframe').locator('span').count).to eq(0)
    end
  end

  it 'should click in lazy iframe', sinatra: true do
    sinatra.get('/iframe.html') { '<html><button>Hello iframe</button></html>' }
    with_page do |page|
      # empty pge
      page.goto(server_empty_page)

      Concurrent::Promises.schedule(0.5) do
        # add blank iframe
        page.evaluate(<<~JAVASCRIPT)
        () => {
          const iframe = document.createElement('iframe');
          document.body.appendChild(iframe);
        }
        JAVASCRIPT
      end

      Concurrent::Promises.schedule(1) do
        # navigate iframe
        page.evaluate("() => document.querySelector('iframe').src = 'iframe.html'")
      end

      # Click in iframe
      button = page.frame_locator('iframe').locator('button')
      promises = Concurrent::Promises.zip(
        Concurrent::Promises.future(button, &:click),
        Concurrent::Promises.future(button, &:inner_text),
      )
      results = Timeout.timeout(2) { promises.value! }
      expect(results.last).to eq('Hello iframe')
    end
  end

  it 'waitFor should survive frame reattach', sinatra: true, route: :iframe do
    with_page do |page|
      page.goto(server_empty_page)
      button = page.frame_locator('iframe').locator('button:has-text("Hello nested iframe")')
      promise = Concurrent::Promises.future(button, &:wait_for)
      page.locator('iframe').evaluate('e => e.remove()')
      page.evaluate(<<~JAVASCRIPT)
      () => {
        const iframe = document.createElement('iframe');
        iframe.src = 'iframe-2.html';
        document.body.appendChild(iframe);
      }
      JAVASCRIPT
      Timeout.timeout(2) do
        promise.value!
      end
    end
  end

  it 'click should survive frame reattach', sinatra: true, route: :iframe do
    with_page do |page|
      page.goto(server_empty_page)
      button = page.frame_locator('iframe').locator('button:has-text("Hello nested iframe")')
      promise = Concurrent::Promises.future(button, &:click)
      page.locator('iframe').evaluate('e => e.remove()')
      page.evaluate(<<~JAVASCRIPT)
      () => {
        const iframe = document.createElement('iframe');
        iframe.src = 'iframe-2.html';
        document.body.appendChild(iframe);
      }
      JAVASCRIPT
      Timeout.timeout(2) do
        promise.value!
      end
    end
  end

  it 'click should survive iframe navigation', sinatra: true, route: :iframe do
    with_page do |page|
      page.goto(server_empty_page)
      button = page.frame_locator('iframe').locator('button:has-text("Hello nested iframe")')
      promise = Concurrent::Promises.future(button, &:click)
      page.locator('iframe').evaluate("e => e.src = 'iframe-2.html'")
      Timeout.timeout(2) do
        promise.value!
      end
    end
  end

  it 'should non work for non-frame' do
    with_page do |page|
      page.content = '<div></div>'
      expect { page.frame_locator('div').locator('button').wait_for }.to raise_error(/<iframe> was expected/)
    end
  end

  it 'locator.frameLocator should work for iframe', sinatra: true, route: :iframe do
    with_page do |page|
      page.goto(server_empty_page)
      button = page.locator('body').frame_locator('iframe').locator('button')
      button.wait_for
      expect(button.inner_text).to eq('Hello iframe')
      button.click
    end
  end

  it 'locator.frameLocator should throw on ambiguity', sinatra: true, route: :ambiguous do
    with_page do |page|
      page.goto(server_empty_page)
      button = page.locator('body').frame_locator('iframe').locator('button')
      expect { button.wait_for }.to raise_error(/Error: strict mode violation: "body >> iframe" resolved to 3 elements/)
    end
  end

  it 'locator.frameLocator should throw on first/last/nth', sinatra: true, route: :ambiguous do
    with_page do |page|
      page.goto(server_empty_page)
      button1 = page.locator('body').frame_locator('iframe').first.locator('button')
      expect(button1.inner_text).to eq('Hello from iframe-1')
      button2 = page.locator('body').frame_locator('iframe').nth(1).locator('button')
      expect(button2.inner_text).to eq('Hello from iframe-2')
      button3 = page.locator('body').frame_locator('iframe').last.locator('button')
      expect(button3.inner_text).to eq('Hello from iframe-3')
    end
  end
end
