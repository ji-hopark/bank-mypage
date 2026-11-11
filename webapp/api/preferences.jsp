<%@ page contentType="application/json; charset=UTF-8" pageEncoding="UTF-8" trimDirectiveWhitespaces="true" isErrorPage="true" %>
<%@ include file="../WEB-INF/runtime.jsp" %>

<% try { requireMethod(request,"POST");
JsonObject b=readBody(request);boolean consent=checkedBoolean(b,"notificationConsent");
 synchronized(application) {JsonObject p=state(application,"profile",seed(application,"profile")).getAsJsonObject();p.addProperty("notificationConsent",consent);saveState("profile",p);writeJson(response,out,Map.of("profile",p));}
} catch(Exception ex) {writeError(response,out,ex);} %>
