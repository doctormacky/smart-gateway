package com.jsjf.ai.smartgateway.http;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.apache.apisix.plugin.runner.HttpResponse;

import java.util.HashMap;
import java.util.Map;

/**
 * 统一响应处理工具类
 * <p>
 * 为 APISIX Java Plugin Runner 提供标准化的 HTTP 响应构建功能，
 * 支持认证失败、系统错误等多种场景的统一响应格式。
 * </p>
 *
 * <p>响应格式示例：</p>
 * <pre>
 * {
 *   "success": false,
 *   "code": "AUTH_001",
 *   "message": "未提供认证令牌",
 *   "timestamp": 1699999999999
 * }
 * </pre>
 *
 * @author Macky (liuyun105@126.com)
 * @version 2.0.0
 * @since 2025-11-13
 */
@Slf4j
public final class ResponseDTO {

    /**
     * 响应内容类型常量
     */
    private static final String CONTENT_TYPE = "Content-Type";
    private static final String APPLICATION_JSON_UTF8 = "application/json; charset=utf-8";

    /**
     * JSON 序列化工具（线程安全）
     */
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    /**
     * 错误码常量
     */
    public static final class ErrorCode {
        /** 未提供认证令牌 */
        public static final String MISSING_TOKEN = "AUTH_001";
        /** 令牌格式错误 */
        public static final String INVALID_FORMAT = "AUTH_002";
        /** 令牌为空 */
        public static final String EMPTY_TOKEN = "AUTH_003";
        /** 令牌无效或已过期 */
        public static final String TOKEN_EXPIRED = "AUTH_004";
        /** 系统内部错误 */
        public static final String SYSTEM_ERROR = "SYS_500";

        private ErrorCode() {
            throw new UnsupportedOperationException("Utility class");
        }
    }

    /**
     * 私有构造函数，防止实例化
     */
    private ResponseDTO() {
        throw new UnsupportedOperationException("Utility class cannot be instantiated");
    }

    /**
     * 构建标准错误响应体
     *
     * @param code    错误码
     * @param message 错误消息
     * @return JSON 格式的错误响应字符串
     */
    private static String buildErrorResponse(String code, String message) {
        Map<String, Object> response = new HashMap<>(4);
        response.put("success", false);
        response.put("code", code);
        response.put("message", message);
        response.put("timestamp", System.currentTimeMillis());

        try {
            return OBJECT_MAPPER.writeValueAsString(response);
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize error response", e);
            // 降级方案：返回简单的 JSON 字符串
            return String.format(
                "{\"success\":false,\"code\":\"%s\",\"message\":\"%s\",\"timestamp\":%d}",
                code, message, System.currentTimeMillis()
            );
        }
    }

    /**
     * 设置响应的通用方法
     *
     * @param response   HttpResponse 对象
     * @param statusCode HTTP 状态码
     * @param body       响应体内容
     */
    private static void setResponse(HttpResponse response, int statusCode, String body) {
        response.setBody(body);
        response.setHeader(CONTENT_TYPE, APPLICATION_JSON_UTF8);
        response.setStatusCode(statusCode);
    }

    /**
     * 未提供认证令牌
     * <p>
     * HTTP 状态码: 401 Unauthorized<br>
     * 错误码: AUTH_001<br>
     * 场景: 请求头中缺少 Authorization 字段
     * </p>
     *
     * @param response APISIX HttpResponse 对象
     */
    public static void unauthenticated(HttpResponse response) {
        String body = buildErrorResponse(
            ErrorCode.MISSING_TOKEN,
            "未提供认证令牌，请在请求头中添加 Authorization 字段"
        );
        setResponse(response, 401, body);
    }

    /**
     * 令牌格式错误
     * <p>
     * HTTP 状态码: 401 Unauthorized<br>
     * 错误码: AUTH_002<br>
     * 场景: Authorization 格式不符合 "Bearer {token}" 规范
     * </p>
     *
     * @param response APISIX HttpResponse 对象
     */
    public static void formatError(HttpResponse response) {
        String body = buildErrorResponse(
            ErrorCode.INVALID_FORMAT,
            "令牌格式错误，正确格式为: Bearer {token}"
        );
        setResponse(response, 401, body);
    }

    /**
     * 令牌为空
     * <p>
     * HTTP 状态码: 401 Unauthorized<br>
     * 错误码: AUTH_003<br>
     * 场景: Bearer 后面的 token 内容为空
     * </p>
     *
     * @param response APISIX HttpResponse 对象
     */
    public static void emptyToken(HttpResponse response) {
        String body = buildErrorResponse(
            ErrorCode.EMPTY_TOKEN,
            "令牌内容为空，请提供有效的令牌"
        );
        setResponse(response, 401, body);
    }

    /**
     * 令牌无效或已过期
     * <p>
     * HTTP 状态码: 401 Unauthorized<br>
     * 错误码: AUTH_004<br>
     * 场景: Redis 中未找到对应的 token 记录或已失效
     * </p>
     *
     * @param response APISIX HttpResponse 对象
     */
    public static void invalidOrExpired(HttpResponse response) {
        String body = buildErrorResponse(
            ErrorCode.TOKEN_EXPIRED,
            "令牌无效或已过期，请重新登录"
        );
        setResponse(response, 401, body);
    }

    /**
     * 系统内部错误
     * <p>
     * HTTP 状态码: 500 Internal Server Error<br>
     * 错误码: SYS_500<br>
     * 场景: Token 验证过程中发生异常
     * </p>
     *
     * @param response APISIX HttpResponse 对象
     * @param cause    异常原因（可选）
     */
    public static void systemError(HttpResponse response, String cause) {
        String message = cause != null && !cause.isEmpty()
            ? "系统内部错误: " + cause
            : "系统内部错误，请稍后重试";

        String body = buildErrorResponse(ErrorCode.SYSTEM_ERROR, message);
        setResponse(response, 500, body);
    }

    /**
     * 系统内部错误（无具体原因）
     *
     * @param response APISIX HttpResponse 对象
     */
    public static void systemError(HttpResponse response) {
        systemError(response, null);
    }
}
