require 'base64'

module Playwright
  define_channel_owner :APIRequestContext do
    private def after_initialize
      @tracing = ChannelOwners::Tracing.from(@initializer['tracing'])
    end

    def dispose
      @channel.send_message_to_server('dispose')
    end

    def delete(
          url,
          data: nil,
          failOnStatusCode: nil,
          form: nil,
          headers: nil,
          ignoreHTTPSErrors: nil,
          multipart: nil,
          params: nil,
          timeout: nil)
      fetch(
        url,
        method: 'DELETE',
        data: data,
        failOnStatusCode: failOnStatusCode,
        form: form,
        headers: headers,
        ignoreHTTPSErrors: ignoreHTTPSErrors,
        multipart: multipart,
        params: params,
        timeout: timeout,
      )
    end

    def head(
          url,
          failOnStatusCode: nil,
          headers: nil,
          ignoreHTTPSErrors: nil,
          params: nil,
          timeout: nil)
      fetch(
        url,
        method: 'HEAD',
        failOnStatusCode: failOnStatusCode,
        headers: headers,
        ignoreHTTPSErrors: ignoreHTTPSErrors,
        params: params,
        timeout: timeout,
      )
    end

    def get(
          url,
          failOnStatusCode: nil,
          headers: nil,
          ignoreHTTPSErrors: nil,
          params: nil,
          timeout: nil)
      fetch(
        url,
        method: 'GET',
        failOnStatusCode: failOnStatusCode,
        headers: headers,
        ignoreHTTPSErrors: ignoreHTTPSErrors,
        params: params,
        timeout: timeout,
      )
    end

    def patch(
          url,
          data: nil,
          failOnStatusCode: nil,
          form: nil,
          headers: nil,
          ignoreHTTPSErrors: nil,
          multipart: nil,
          params: nil,
          timeout: nil)
      fetch(
        url,
        method: 'PATCH',
        data: data,
        failOnStatusCode: failOnStatusCode,
        form: form,
        headers: headers,
        ignoreHTTPSErrors: ignoreHTTPSErrors,
        multipart: multipart,
        params: params,
        timeout: timeout,
      )
    end

    def put(
          url,
          data: nil,
          failOnStatusCode: nil,
          form: nil,
          headers: nil,
          ignoreHTTPSErrors: nil,
          multipart: nil,
          params: nil,
          timeout: nil)
      fetch(
        url,
        method: 'PUT',
        data: data,
        failOnStatusCode: failOnStatusCode,
        form: form,
        headers: headers,
        ignoreHTTPSErrors: ignoreHTTPSErrors,
        multipart: multipart,
        params: params,
        timeout: timeout,
      )
    end

    def post(
          url,
          data: nil,
          failOnStatusCode: nil,
          form: nil,
          headers: nil,
          ignoreHTTPSErrors: nil,
          multipart: nil,
          params: nil,
          timeout: nil)
      fetch(
        url,
        method: 'POST',
        data: data,
        failOnStatusCode: failOnStatusCode,
        form: form,
        headers: headers,
        ignoreHTTPSErrors: ignoreHTTPSErrors,
        multipart: multipart,
        params: params,
        timeout: timeout,
      )
    end

    def fetch(
          urlOrRequest,
          data: nil,
          failOnStatusCode: nil,
          form: nil,
          headers: nil,
          ignoreHTTPSErrors: nil,
          method: nil,
          multipart: nil,
          params: nil,
          timeout: nil)

      if [ChannelOwners::Request, String].none? { |type| urlOrRequest.is_a?(type) }
        raise ArgumentError.new("First argument must be either URL string or Request")
      end
      if [data, form, multipart].compact.count > 1
        raise ArgumentError.new("Only one of 'data', 'form' or 'multipart' can be specified")
      end

      request = urlOrRequest.is_a?(ChannelOwners::Request) ? urlOrRequest : nil
      headers_obj = headers || request&.headers
      fetch_params = {
        url: request&.url || urlOrRequest,
        params: object_to_array(params),
        method: method || request&.method || 'GET',
        headers: headers_obj ? HttpHeaders.new(headers_obj).as_serialized : nil,
      }

      json_data = nil
      form_data = nil
      multipart_data = nil
      post_data_buffer = nil
      if data
        case data
        when String
          if headers_obj&.any? { |key, value| key.downcase == 'content-type' && value == 'application/json' }
            json_data = data
          else
            post_data_buffer = data
          end
        when Hash, Array, Numeric, true, false
          json_data = data
        else
          raise ArgumentError.new("Unsupported 'data' type: #{data.class}")
        end
      elsif form
        form_data = object_to_array(form)
      elsif multipart
        multipart_data = multipart.map do |name, value|
          if file_payload?(value)
            { name: name, file: file_payload_to_json(value) }
          else
            { name: name, value: value.to_s }
          end
        end
      end

      if !json_data && !form_data && !multipart_data
        post_data_buffer ||= request&.post_data_buffer
      end
      if post_data_buffer
        fetch_params[:postData] = Base64.strict_encode64(post_data_buffer)
      end

      fetch_params[:jsonData] = json_data
      fetch_params[:formData] = form_data
      fetch_params[:multipartData] = multipart_data
      fetch_params[:timeout] = timeout
      fetch_params[:failOnStatusCode] = failOnStatusCode
      fetch_params[:ignoreHTTPSErrors] = ignoreHTTPSErrors
      fetch_params.compact!
      response = @channel.send_message_to_server('fetch', fetch_params)

      APIResponseImpl.new(self, response)
    end

    private def file_payload?(value)
      value.is_a?(Hash) &&
        %w(name mimeType buffer).all? { |key| value.has_key?(key) || value.has_key?(key.to_sym) }
    end

    private def file_payload_to_json(payload)
      {
        name: payload[:name] || payload['name'],
        mimeType: payload[:mimeType] || payload['mimeType'],
        buffer: Base64.strict_encode64(payload[:buffer] || payload['buffer'])
      }
    end

    private def object_to_array(hash)
      hash&.map do |key, value|
        { name: key, value: value.to_s }
      end
    end
  end
end
