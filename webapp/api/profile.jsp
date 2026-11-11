<%@ page contentType="application/json; charset=UTF-8" pageEncoding="UTF-8" trimDirectiveWhitespaces="true" isErrorPage="true" %>
<%@ include file="../WEB-INF/runtime.jsp" %>

<% try { requireMethod(request,"GET");
synchronized(application) {writeJson(response,out,Map.of("profile",state(application,"profile",seed(application,"profile"))));}
} catch(Exception ex) {writeError(response,out,ex);} %>
