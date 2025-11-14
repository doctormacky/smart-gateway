package com.jsjf.ai.smartgateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = {"com.jsjf.ai.smartgateway","org.apache.apisix.plugin.runner"})
public class SmartGatewayApplication {
	public static void main(String[] args) {
		SpringApplication.run(SmartGatewayApplication.class, args);
	}

}
