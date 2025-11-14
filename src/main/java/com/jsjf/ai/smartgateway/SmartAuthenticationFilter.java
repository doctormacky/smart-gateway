package com.jsjf.ai.smartgateway;

import cn.dev33.satoken.SaManager;
import cn.dev33.satoken.dao.SaTokenDao;
import com.jsjf.ai.smartgateway.http.ResponseDTO;
import lombok.extern.slf4j.Slf4j;
import org.apache.apisix.plugin.runner.HttpRequest;
import org.apache.apisix.plugin.runner.HttpResponse;
import org.apache.apisix.plugin.runner.filter.PluginFilter;
import org.apache.apisix.plugin.runner.filter.PluginFilterChain;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;

/**
 * Smart 认证过滤器
 * <p>
 * 基于 Sa-Token 和 Redis 的分布式认证过滤器，用于 APISIX API 网关的请求鉴权。<br>
 * 该过滤器作为 APISIX Java Plugin Runner 的外部插件运行，通过验证 HTTP 请求头中的
 * Bearer Token 来确定用户身份。
 * </p>
 *
 * <h3>功能特性</h3>
 * <ul>
 *   <li>支持 Bearer Token 认证机制</li>
 *   <li>基于 Redis 的分布式 Session 存储</li>
 *   <li>与 Sa-Token 框架无缝集成</li>
 *   <li>提供统一的错误响应格式</li>
 * </ul>
 *
 * <h3>使用示例</h3>
 * <pre>
 * // 在 APISIX 路由配置中启用
 * {
 *   "plugins": {
 *     "ext-plugin-pre-req": {
 *       "conf": [
 *         {
 *           "name": "SmartAuthenticationFilter",
 *           "value": "{}"
 *         }
 *       ]
 *     }
 *   }
 * }
 * </pre>
 *
 * <h3>HTTP 请求头格式</h3>
 * <pre>
 * Authorization: Bearer {your_token_here}
 * </pre>
 *
 * @author Macky (liuyun105@126.com)
 * @version 2.0.0
 * @since 2025-11-10
 * @see PluginFilter
 * @see ResponseDTO
 */
@Slf4j
@Component
public class SmartAuthenticationFilter implements PluginFilter, InitializingBean {

    // ==================== 常量配置 ====================

    /**
     * 插件名称，必须与 APISIX 路由配置中的 name 字段一致
     */
    private static final String PLUGIN_NAME = "SmartAuthenticationFilter";

    /**
     * Authorization 请求头对应的 Nginx 变量名
     */
    private static final String NGINX_VAR_AUTHORIZATION = "http_authorization";

    /**
     * Bearer Token 前缀
     */
    private static final String TOKEN_PREFIX = "Bearer ";

    /**
     * Sa-Token 默认的登录类型
     */
    private static final String DEFAULT_LOGIN_TYPE = "login";

    /**
     * Redis Key 分隔符
     */
    private static final String REDIS_KEY_SEPARATOR = ":";

    // ==================== 生命周期回调 ====================

    /**
     * Bean 初始化回调
     * <p>
     * 在 Spring 容器初始化该 Bean 后调用，用于输出插件加载日志。
     * </p>
     */
    @Override
    public void afterPropertiesSet() {
        log.info("========================================");
        log.info("  Smart Gateway Authentication Plugin  ");
        log.info("  Plugin Name: {}", PLUGIN_NAME);
        log.info("  Status: INITIALIZED");
        log.info("========================================");
    }

    // ==================== PluginFilter 接口实现 ====================

    /**
     * 返回插件名称
     * <p>
     * 该名称必须与 APISIX 路由配置中的 <code>ext-plugin-pre-req.conf[].name</code> 字段严格匹配。
     * </p>
     *
     * @return 插件名称
     */
    @Override
    public String name() {
        return PLUGIN_NAME;
    }

    /**
     * 声明需要使用的 Nginx 变量
     * <p>
     * APISIX Java Plugin Runner 通过 Nginx 变量获取 HTTP 请求头。<br>
     * 格式：<code>http_{header_name}</code>，其中 header_name 为小写并以下划线替换连字符。
     * </p>
     *
     * <p>示例：</p>
     * <ul>
     *   <li><code>Authorization</code> → <code>http_authorization</code></li>
     *   <li><code>User-Agent</code> → <code>http_user_agent</code></li>
     * </ul>
     *
     * @return Nginx 变量名称列表
     */
    @Override
    public List<String> requiredVars() {
        return Collections.singletonList(NGINX_VAR_AUTHORIZATION);
    }

    /**
     * 过滤器核心逻辑
     * <p>
     * 对每个请求执行以下验证流程：
     * </p>
     * <ol>
     *   <li>检查 Authorization 请求头是否存在</li>
     *   <li>验证 Token 是否以 "Bearer " 开头</li>
     *   <li>提取并检查 Token 内容是否为空</li>
     *   <li>从 Redis 中查询 Token 对应的用户信息</li>
     *   <li>验证通过后继续请求链，否则返回错误响应</li>
     * </ol>
     *
     * <p><strong>重要：</strong></p>
     * <ul>
     *   <li>无论验证成功还是失败，都必须调用 <code>chain.filter()</code></li>
     *   <li>设置非 2xx 状态码时，APISIX 会直接返回响应，不转发给上游</li>
     * </ul>
     *
     * @param request  APISIX HTTP 请求对象
     * @param response APISIX HTTP 响应对象
     * @param chain    过滤器链
     */
    @Override
    public void filter(HttpRequest request, HttpResponse response, PluginFilterChain chain) {
        try {
            // 1. 获取 Authorization 请求头
            String authorization = extractAuthorization(request);
            if (authorization == null) {
                log.debug("Authentication failed: Missing Authorization header");
                ResponseDTO.unauthenticated(response);
                chain.filter(request, response);
                return;
            }

            // 2. 验证 Token 格式
            if (!authorization.startsWith(TOKEN_PREFIX)) {
                log.debug("Authentication failed: Invalid token format, expected 'Bearer {{token}}'");
                ResponseDTO.formatError(response);
                chain.filter(request, response);
                return;
            }

            // 3. 提取纯 Token
            String pureToken = extractToken(authorization);
            if (pureToken == null || pureToken.isEmpty()) {
                log.debug("Authentication failed: Empty token content");
                ResponseDTO.emptyToken(response);
                chain.filter(request, response);
                return;
            }

            // 4. 验证 Token 有效性
            if (!validateToken(pureToken)) {
                log.debug("Authentication failed: Invalid or expired token");
                ResponseDTO.invalidOrExpired(response);
                chain.filter(request, response);
                return;
            }

            // 5. 验证通过，继续请求链
            log.debug("Authentication successful, token: {}", maskToken(pureToken));
            chain.filter(request, response);

        } catch (Exception e) {
            log.error("Unexpected error during token validation", e);
            ResponseDTO.systemError(response, e.getMessage());
            chain.filter(request, response);
        }
    }

    // ==================== 私有辅助方法 ====================

    /**
     * 从请求中提取 Authorization 请求头
     *
     * @param request HTTP 请求对象
     * @return Authorization 值，如果不存在或为空则返回 null
     */
    private String extractAuthorization(HttpRequest request) {
        String authorization = request.getVars(NGINX_VAR_AUTHORIZATION);
        return (authorization != null && !authorization.trim().isEmpty()) ? authorization.trim() : null;
    }

    /**
     * 从 Authorization 请求头中提取纯 Token
     *
     * @param authorization Authorization 请求头值（包含 "Bearer " 前缀）
     * @return 纯 Token 字符串
     */
    private String extractToken(String authorization) {
        return authorization.substring(TOKEN_PREFIX.length()).trim();
    }

    /**
     * 验证 Token 在 Redis 中是否存在且有效
     * <p>
     * Redis Key 格式：<code>{tokenName}:{loginType}:token:{token}</code><br>
     * 示例：<code>satoken:login:token:abc123</code>
     * </p>
     *
     * @param token 纯 Token 字符串
     * @return 如果 Token 有效返回 true，否则返回 false
     */
    private boolean validateToken(String token) {
        try {
            // 构建 Redis Key
            String redisKey = buildRedisKey(token);
            log.debug("Validating token in Redis, key: {}", redisKey);

            // 查询 Redis
            SaTokenDao tokenDao = SaManager.getSaTokenDao();
            String tokenValue = tokenDao.get(redisKey);

            if (tokenValue == null || tokenValue.isEmpty()) {
                log.debug("Token not found or expired in Redis, key: {}", redisKey);
                return false;
            }

            log.debug("Token validation successful, user data exists");
            return true;

        } catch (Exception e) {
            log.error("Failed to validate token in Redis", e);
            return false;
        }
    }

    /**
     * 构建 Redis Key
     * <p>
     * 格式：{tokenName}:{loginType}:token:{token}
     * </p>
     *
     * @param token 纯 Token 字符串
     * @return Redis Key
     */
    private String buildRedisKey(String token) {
        String tokenName = SaManager.getConfig().getTokenName();
        return tokenName +
               REDIS_KEY_SEPARATOR + DEFAULT_LOGIN_TYPE +
               REDIS_KEY_SEPARATOR + "token" +
               REDIS_KEY_SEPARATOR + token;
    }

    /**
     * 掉藏 Token 用于日志输出
     * <p>
     * 将 Token 的中间部分替换为星号，保留前 4 位和后 4 位。
     * </p>
     *
     * @param token 原始 Token
     * @return 掉藏后的 Token，示例："abc1****xyz9"
     */
    private String maskToken(String token) {
        if (token == null || token.length() <= 8) {
            return "****";
        }
        String prefix = token.substring(0, 4);
        String suffix = token.substring(token.length() - 4);
        return prefix + "****" + suffix;
    }
}
