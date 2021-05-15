require 'json'
require 'fileutils'

class PostmanDocGenerator
  attr_accessor :result, :error

  class << self
    def start(http_method, path, controller, response)
      generator = new(http_method, path, controller, response)
      generator.call
    rescue => e
      generator.error = e
    ensure
      generator
    end
  end

  def initialize(http_method, path, controller, response)
    @sample_dir = "#{File.expand_path("#{File.dirname(__FILE__)}/..")}/sample"
    @http_method = http_method.upcase.to_s
    @path = path
    @controller = controller
    @response = response
  end

  def call
    get_basic_setting
    setup_basic_info
    setup_postman_json
    save_to_file
  end

  private

  def get_basic_setting
    env = ENV['RAILS_ENV'] || 'development'
    string = File.open('config/postman_doc_generator.yml', 'rb') { |f| f.read }
    fail 'config/postman_doc_generator.yml not existed nor not readable' if string.nil?
    @config = YAML.load(string)[env]
    fail 'config/postman_doc_generator.yml incorrect or environment not exist' if @config.nil?
    result_dir = @config['postman_dir'] || 'result'
    FileUtils.mkdir_p(result_dir)
    @file_path = "#{result_dir}/postman.json"
  end

  def setup_basic_info
    @params = @controller.params.permit!.to_h.to_json(except: [:format, :controller, :action, :tag, :user_agent])
    @res_status = @response.status
    @res_body =  @response.body.present? ? JSON.parse(@response.body) : {}
    data = File.read(@file_path) if File.exist?(@file_path)
    @postman_data = data.blank? ? JSON.parse(File.read("#{@sample_dir}/doc.json") % @config.transform_keys(&:to_sym)) : JSON.parse(data)
  end

  def setup_postman_json
    levels = @controller.class.name.split('::')
    @postman_data['item'] = format_with_levels(levels, @postman_data['item'])
  end

  def save_to_file
    File.open(@file_path, 'w+') do |f|
      f.write(@postman_data.to_json)
    end
  end

  def format_with_levels(levels, pm_items)
    first_level = levels.first
    return format_namespace_requests(pm_items || []) if first_level.nil?
    pm_item = pm_items.find do |item|
      item['name'] == first_level
    end
    if pm_item.nil?
      pm_items << {name: first_level, item: format_with_levels(levels[1..-1], [])}
    else
      pm_item['item'] = format_with_levels(levels[1..-1], pm_item['item'])
    end
    pm_items
  end

  def format_namespace_requests(namespace_requests)
    target_req = namespace_requests.find do |r|
      req = r['request']
      req['method'] == @http_method && req['url']['raw'] == "#{@config['project_host']}#{@path}"
    end
    request = setup_request(target_req)
    target_req.present? ? (target_req = request) : namespace_requests << request
    namespace_requests
  end

  def setup_request(target_req)
    if @res_status == 200 || target_req.nil?
      request = JSON.parse(File.read("#{@sample_dir}/request.json"))
      request['name'] = "#{@http_method} #{@path}"
      req = request['request']
      req['method'] = @http_method
      req['body']['raw'] = @params.to_json
      req['url']['raw'] = "#{@config['project_host']}#{@path}"
      req['url']['host'] = [@config['project_host']]
      req['url']['path'] = @path.split('/').delete_if(&:blank?)
    else
      request = target_req
    end
    request['response'] = format_responses_of_request(request, target_req&.dig('response') || [])
    request
  end

  def format_responses_of_request(request, responses)
    target_res = responses.find do |res|
      next false unless res['code'] == @res_status
      break true if @res_status == 200
      body = JSON.parse(res['body'])
      body['error_code'] == @res_body['error_code']
    end
    response = setup_response(request['request'], target_res)
    target_res.present? ? (target_res = response) : responses << response
    responses
  end

  def setup_response(request, target_res)
    response = JSON.parse(File.read("#{@sample_dir}/response.json"))
    result = @res_status == 200 ? 'Success' : 'Failed'
    status_text = Rack::Utils::HTTP_STATUS_CODES[@res_status]
    error_code = " #{@res_body['error_code']}" unless @res_status == 200
    response['name'] = "#{@http_method} #{@path} #{result} (#{status_text}#{error_code})"
    response['originalRequest'] = request.except('description')
    response['status'] = status_text
    response['code'] = @res_status
    response['header'] = @response.header.map do |key, value|
      {key: key, value: value}
    end
    response['body'] = @res_body.to_json
    response
  end

end
