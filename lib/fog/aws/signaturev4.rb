# See http://docs.amazonwebservices.com/general/latest/gr/signature-version-4.html
#
module Fog
  module AWS
    class SignatureV4
      def initialize(aws_access_key_id, secret_key, region,service)
        @region = region
        @service = service
        @aws_access_key_id  = aws_access_key_id
        @hmac = Fog::HMAC.new('sha256', 'AWS4' + secret_key)
      end

      def sign(params, date)
        canonical_request = <<-DATA
#{params[:method].to_s.upcase}
#{params[:path]}
#{canonical_query_string(params[:query])}
#{canonical_headers(params[:headers])}
#{signed_headers(params[:headers])}
#{Digest::SHA256.hexdigest(params[:body] || '')}
DATA
        canonical_request.chop!
        credential_scope = "#{date.utc.strftime('%Y%m%d')}/#{@region}/#{@service}/aws4_request"
        string_to_sign = <<-DATA
AWS4-HMAC-SHA256
#{date.to_iso8601_basic}
#{credential_scope}
#{Digest::SHA256.hexdigest(canonical_request)}
DATA

        string_to_sign.chop!

        signature = derived_hmac(date).sign(string_to_sign)

        "AWS4-HMAC-SHA256 Credential=#{@aws_access_key_id}/#{credential_scope}, SignedHeaders=#{signed_headers(params[:headers])}, Signature=#{signature.unpack('H*').first}"
      end

      protected

      def canonical_query_string(query)
        canonical_query_string = []
        for key in (query || {}).keys.sort
          component = "#{Fog::AWS.escape(key)}=#{Fog::AWS.escape(query[key].to_s)}"
          canonical_query_string << component
        end
        canonical_query_string.join("&")
      end

      def canonical_headers(headers)
        canonical_headers = ''

        for key in headers.keys.sort
          canonical_headers << "#{key.downcase}:#{headers[key].to_s.strip}\n"
        end
        canonical_headers
      end

      def signed_headers(headers)
        headers.keys.sort.collect {|key| key.downcase}.join(';')
      end

      def derived_hmac(date)
        kDate = @hmac.sign(date.utc.strftime('%Y%m%d'))
        kRegion = Fog::HMAC.new('sha256', kDate).sign(@region)
        kService = Fog::HMAC.new('sha256', kRegion).sign(@service)
        kSigning = Fog::HMAC.new('sha256', kService).sign('aws4_request')
        Fog::HMAC.new('sha256', kSigning)
      end


    end
  end
end