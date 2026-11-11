<%@ page pageEncoding="UTF-8" import="java.time.*,java.text.NumberFormat,javax.servlet.ServletContext,java.util.*,java.io.*,java.net.*,java.nio.charset.StandardCharsets,java.nio.file.*,com.google.gson.*,javax.servlet.http.*,javax.servlet.jsp.JspWriter" %>
<%!
    private static final Gson GSON = new GsonBuilder().setStrictness(Strictness.STRICT).serializeNulls().disableHtmlEscaping().setPrettyPrinting().create();
    private static class ApiException extends RuntimeException {
        final int status;
        ApiException(int status, String message) { super(message); this.status=status; }
    }
    private String env(String name, String fallback) {
        String value=System.getenv(name); return value==null || value.isBlank() ? fallback : value;
    }
    private String encode(String value) { return URLEncoder.encode(value, StandardCharsets.UTF_8); }
    private void requireMethod(HttpServletRequest req, String method) {
        if (!method.equals(req.getMethod())) throw new ApiException(405, method+" 요청만 지원합니다.");
    }
    private JsonObject readBody(HttpServletRequest req) throws IOException {
        req.setCharacterEncoding("UTF-8");
        if (req.getContentType()==null || !req.getContentType().split(";",2)[0].trim().equalsIgnoreCase("application/json"))
            throw new ApiException(415,"application/json 요청이 필요합니다.");
        StringBuilder text=new StringBuilder(); char[] buffer=new char[2048]; int n;
        while ((n=req.getReader().read(buffer))!=-1) {
            text.append(buffer,0,n); if(text.length()>65536) throw new ApiException(413,"요청이 너무 큽니다.");
        }
        try {
            JsonElement value=GSON.fromJson(text.toString(),JsonElement.class);
            if(value==null || !value.isJsonObject()) throw new ApiException(400,"JSON 객체가 필요합니다.");
            return value.getAsJsonObject();
        } catch (JsonParseException | IllegalStateException ex) { throw new ApiException(400,"올바른 JSON 객체가 필요합니다."); }
    }
    private String stringValue(JsonObject obj,String key) {
        JsonElement value=obj.get(key);
        if(value==null || !value.isJsonPrimitive() || !value.getAsJsonPrimitive().isString()) throw new ApiException(400,key+" 문자열이 필요합니다.");
        return value.getAsString();
    }
    private void writeJson(HttpServletResponse res,JspWriter writer,Object value) throws IOException {
        res.setHeader("Cache-Control","no-store"); res.setHeader("X-Content-Type-Options","nosniff");
        writer.print(GSON.toJson(value));
    }
    private void writeError(HttpServletResponse res,JspWriter writer,Exception ex) throws IOException {
        int status=ex instanceof ApiException ? ((ApiException)ex).status : ex instanceof IOException ? 502 : 400;
        res.setStatus(status);
        writeJson(res,writer,Map.of("error",status==502 ? "연계 서비스에 연결할 수 없습니다." : (ex.getMessage()==null ? "요청을 확인해 주세요." : ex.getMessage())));
    }
    private JsonObject getJson(String service,String path) throws IOException {
        String fallback="http://bank-"+service.toLowerCase(Locale.ROOT)+":8080";
        URL url=URI.create(env(service.toUpperCase(Locale.ROOT)+"_URL",fallback)+path).toURL();
        HttpURLConnection conn=(HttpURLConnection)url.openConnection();
        conn.setConnectTimeout(2500);conn.setReadTimeout(4000);conn.setRequestProperty("Accept","application/json");
        try {
            int status=conn.getResponseCode();
            if(status!=200) {
                if(status>=400 && status<500) {
                    String message="연계 조회 조건을 확인해 주세요.";
                    try(InputStream body=conn.getErrorStream()) {
                        if(body!=null) { JsonObject error=JsonParser.parseString(new String(body.readAllBytes(),StandardCharsets.UTF_8)).getAsJsonObject(); if(error.has("error")) message=error.get("error").getAsString(); }
                    } catch(Exception ignored) {}
                    throw new ApiException(status,message);
                }
                throw new IOException("Upstream "+service+" HTTP "+status);
            }
            try(InputStream body=conn.getInputStream()) {
                return JsonParser.parseString(new String(body.readAllBytes(),StandardCharsets.UTF_8)).getAsJsonObject();
            } catch(JsonParseException | IllegalStateException ex) { throw new IOException("Invalid upstream JSON",ex); }
        } finally { conn.disconnect(); }
    }
    private long positiveAmount(String raw) {
        if(raw==null || !raw.matches("[0-9]{1,9}")) throw new ApiException(400,"금액은 1원부터 999,999,999원까지의 정수입니다.");
        long value=Long.parseLong(raw);if(value<1) throw new ApiException(400,"금액은 1원 이상이어야 합니다.");return value;
    }
    private static final String CUSTOMER="C001";
    private String h(Object value) { return String.valueOf(value==null?"":value).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;").replace("'","&#39;"); }
    private String money(long value) { return NumberFormat.getIntegerInstance(Locale.KOREA).format(value); }
    private JsonElement seed(ServletContext ctx,String name) throws IOException {
        try(InputStream in=ctx.getResourceAsStream("/WEB-INF/data/"+name+".json")) {
            if(in==null) throw new IOException("Data not available");
            return GSON.fromJson(new String(in.readAllBytes(),StandardCharsets.UTF_8),JsonElement.class);
        }
    }
    private JsonElement state(ServletContext ctx,String name,JsonElement fallback) throws IOException {
        Path f=Path.of(env("DATA_DIR",System.getProperty("java.io.tmpdir")+"/nova-"+env("SERVICE_NAME","demo")),name+".json");
        return Files.exists(f)?GSON.fromJson(Files.readString(f),JsonElement.class):fallback.deepCopy();
    }
    private void saveState(String name,JsonElement value) throws IOException {
        Path dir=Path.of(env("DATA_DIR",System.getProperty("java.io.tmpdir")+"/nova-"+env("SERVICE_NAME","demo")));
        Files.createDirectories(dir);Path tmp=Files.createTempFile(dir,"state-",".tmp");
        try {Files.writeString(tmp,GSON.toJson(value));Files.move(tmp,dir.resolve(name+".json"),StandardCopyOption.REPLACE_EXISTING,StandardCopyOption.ATOMIC_MOVE);}
        finally {Files.deleteIfExists(tmp);}
    }
    private long amount(JsonObject body) {
        JsonElement v=body.get("amount");
        if(v==null || !v.isJsonPrimitive() || !v.getAsJsonPrimitive().isNumber() || !v.toString().matches("[0-9]{1,9}")) throw new ApiException(400,"금액은 1원부터 999,999,999원까지 정수로 입력해 주세요.");
        return positiveAmount(v.getAsString());
    }
    private boolean checkedBoolean(JsonObject body,String key) {
        JsonElement v=body.get(key);
        if(v==null || !v.isJsonPrimitive() || !v.getAsJsonPrimitive().isBoolean()) throw new ApiException(400,key+" 항목을 확인해 주세요.");
        return v.getAsBoolean();
    }
    private String required(JsonObject body,String key,int max) {
        String value=stringValue(body,key).trim();
        if(value.isEmpty() || value.length()>max) throw new ApiException(400,"입력 내용을 확인해 주세요: "+key);
        return value;
    }
    private String requestKey(JsonObject body) {
        String key=required(body,"idempotencyKey",64);
        if(!key.matches("[a-zA-Z0-9-]{16,64}")) throw new ApiException(400,"요청 번호가 올바르지 않습니다.");
        return key;
    }
    private JsonObject myAccount(String id) throws IOException { return getJson("account","/api/account.jsp?id="+encode(id==null?"":id)).getAsJsonObject("account"); }
    private JsonObject myProfile() throws IOException { return getJson("mypage","/api/profile.jsp").getAsJsonObject("profile"); }

%>
