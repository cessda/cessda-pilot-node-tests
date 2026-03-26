package eu.cessda.pilotnode;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.ViewControllerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Ensures static resources are served correctly alongside the /api/data REST
 * controller.
 *
 * <p>Without this, Spring MVC's handler mapping order can cause the {@code /**}
 * mapping in {@link DashboardDataController} to shadow the default static
 * resource handler, resulting in 404 responses for {@code index.html} and
 * {@code node.html}.</p>
 */
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    /**
     * Explicitly registers the classpath static resource handler at the same
     * locations Spring Boot uses by default, but with a defined order that
     * ensures it is checked before the catch-all controller mapping.
     */
    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/**")
                .addResourceLocations("classpath:/static/")
                .resourceChain(true);
    }

    /**
     * Maps the root path {@code /} to {@code index.html} so that both
     * {@code http://localhost:8080/} and {@code http://localhost:8080/index.html}
     * serve the landing page.
     */
    @Override
    public void addViewControllers(ViewControllerRegistry registry) {
        registry.addRedirectViewController("/", "/index.html");
    }
}