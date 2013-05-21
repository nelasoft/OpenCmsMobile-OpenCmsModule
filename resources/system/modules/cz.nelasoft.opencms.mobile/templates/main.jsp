<%@page import="org.dom4j.Document"%>
<%@page import="java.io.StringReader"%>
<%@page import="org.dom4j.io.SAXReader"%>
<%@page import="org.opencms.xml.CmsXmlContentDefinition"%>
<%@page import="java.util.Iterator"%>
<%@page import="org.opencms.xml.CmsXmlGenericWrapper"%>
<%@page import="org.opencms.file.CmsPropertyDefinition"%>
<%@page import="org.opencms.i18n.CmsEncoder"%>
<%@page import="javax.xml.parsers.DocumentBuilder"%>
<%@page import="javax.xml.parsers.DocumentBuilderFactory"%>
<%@page import="org.apache.commons.lang.StringEscapeUtils"%>
<%@page import="org.apache.commons.lang.StringUtils"%>
<%@page import="org.opencms.util.CmsHtmlStripper"%>
<%@page import="org.opencms.main.CmsException"%>
<%@page import="org.opencms.staticexport.CmsLinkManager"%>
<%@page import="org.opencms.util.CmsUriSplitter"%>
<%@page import="org.opencms.flex.CmsFlexController"%>
<%@page import="org.opencms.loader.CmsImageScaler"%>
<%@page import="java.io.StringWriter"%>
<%@page import="java.io.PrintWriter"%>
<%@page import="java.io.Writer"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
<%@page import="org.opencms.main.OpenCms"%>
<%@page import="org.opencms.util.CmsStringUtil"%>
<%@page import="java.util.Collections"%>
<%@page import="org.opencms.file.CmsResourceFilter"%>
<%@page import="java.util.Enumeration"%>
<%@page import="org.opencms.xml.types.I_CmsXmlContentValue"%>
<%@page import="java.util.ArrayList"%>
<%@page import="org.opencms.file.collectors.CmsDefaultResourceCollector"%>
<%@page import="org.opencms.file.collectors.I_CmsResourceCollector"%>
<%@page import="java.util.List"%>
<%@page import="java.util.Locale"%>
<%@page import="org.dom4j.Element"%>
<%@page import="org.opencms.xml.content.CmsXmlContent"%>
<%@page import="org.opencms.file.CmsFile"%>
<%@page import="org.opencms.xml.content.CmsXmlContentFactory"%>
<%@page import="org.opencms.json.XML"%>
<%@page import="org.opencms.file.CmsResource"%>
<%@page import="org.opencms.file.CmsObject"%>
<%@page import="org.opencms.file.CmsRequestContext"%>
<%@page import="org.opencms.jsp.CmsJspActionElement"%>
<%@page import="org.opencms.util.CmsRequestUtil"%>
<%@page import="org.opencms.json.JSONObject"%>
<%@page buffer="none" session="false" taglibs="c,cms,fmt,fn"
	contentType="text/json; charset=UTF-8" pageEncoding="UTF-8"%>
<%!private CmsImageScaler m_scaler = new CmsImageScaler();

	private Element getMainElement(CmsObject cmsObj, Locale locale, Locale defaultLocale, CmsFile resource) throws Exception {

		String encoding = null;
		try {
			encoding = cmsObj.readPropertyObject(resource, CmsPropertyDefinition.PROPERTY_CONTENT_ENCODING, true).getValue();
		} catch (CmsException e) {
		}

		if (encoding == null) {
			encoding = OpenCms.getSystemInfo().getDefaultEncoding();
		} else {
			encoding = CmsEncoder.lookupEncoding(encoding, null);
		}

		SAXReader reader = new SAXReader();
		Document document = reader.read(new StringReader(new String(resource.getContents(), encoding)));

		String localeStr = locale.toString();

		Iterator<Element> i = CmsXmlGenericWrapper.elementIterator(document.getRootElement());

		Element defaultElement = null;

		while (i.hasNext()) {
			Element element = i.next();

			String locStr = element.attributeValue(CmsXmlContentDefinition.XSD_ATTRIBUTE_VALUE_LANGUAGE);

			if (isLocaleMatching(locale, locStr)) {
				return element;
			}

			if (isLocaleMatching(defaultLocale, locStr)) {
				defaultElement = element;
			}
		}

		return defaultElement;
	}

	private boolean isLocaleMatching(Locale locale, String locStr) {
		if (locStr.startsWith(locale.toString())) {
			return true;
		}
		Locale tmpLoc = new Locale(locale.getLanguage());
		if (locStr.startsWith(tmpLoc.toString())) {
			return true;
		}
		return false;
	}

	private String getJsonFromFile(CmsObject cmsObj, Locale locale, Locale defaultLocale, CmsResource resource) throws Exception {
		if (resource == null) {
			return "{}";
		}
		CmsFile file = cmsObj.readFile(resource);
		CmsXmlContent content = CmsXmlContentFactory.unmarshal(cmsObj, file);

		Element el = getMainElement(cmsObj, locale, defaultLocale, file);

		StringBuilder sb = new StringBuilder();
		sb.append("{\"");
		sb.append(el.getName());
		sb.append("\":{\"Tabs\":[");

		List<Element> elements = el.element("Tabs").elements();
		boolean isFirst = true;
		for (Element element : elements) {
			element.setName("Tab");
		
			if (isFirst) {
				isFirst = false;
			}
			else {
				sb.append(",");
			}
			String jsonElement = XML.toJSONObject(element.asXML()).toString();
			//jsonElement = StringUtils.removeStart(jsonElement, "{");
			//jsonElement = StringUtils.removeEnd(jsonElement, "}");
			sb.append(jsonElement);
		}
		sb.append("]}}");
		
	
		return sb.toString();
	}

	private String getJsonFromFiles(CmsObject cmsObj, Locale locale, Locale defaultLocale, List<CmsResource> resources) throws Exception {
		if (resources == null || resources.isEmpty()) {
			return "{}";
		}

		String mainElement = getParentElementName(cmsObj, locale, defaultLocale, resources.get(0));
		StringBuilder sb = new StringBuilder();
		sb.append("{\"");
		sb.append(mainElement);
		sb.append("\":[");

		for (int i = 0; i < resources.size(); i++) {
			CmsResource resource = resources.get(i);
			if (i != 0) {
				sb.append(",");
			}
			CmsFile file = cmsObj.readFile(resource);

			Element el = getMainElement(cmsObj, locale, defaultLocale, file);
			JSONObject json = XML.toJSONObject(el.asXML());
			sb.append(json.toString());
		}

		sb.append("]}");
		return sb.toString();
	}

	private String getParentElementName(CmsObject cmsObj, Locale locale, Locale defaultLocale, CmsResource resource) throws Exception {
		CmsFile file = cmsObj.readFile(resource);

		Element el = getMainElement(cmsObj, locale, defaultLocale, file);
		return el.getParent().getName();
	}

	private String getStringValue(CmsXmlContent content, String path, Locale locale, CmsObject cmsObj, String defaultValue) {
		if (!content.hasValue(path, locale)) {
			return defaultValue;
		}
		I_CmsXmlContentValue value = content.getValue(path, locale);
		if (value == null) {
			return defaultValue;
		}
		String result = value.getStringValue(cmsObj);

		if (CmsStringUtil.isEmptyOrWhitespaceOnly(result)) {
			return defaultValue;
		}

		result = result.replaceAll("\\<.*?\\>", "");
		result = StringEscapeUtils.unescapeHtml(result);
		return result;
	}

	private String getStringValue(CmsXmlContent content, String path, Locale locale, CmsObject cmsObj) {
		return getStringValue(content, path, locale, cmsObj, null);
	}

	/**
	 * Internal action method to create the tag content.<p>
	 * 
	 * @param src the image source
	 * @param scaler the image scaleing parameters 
	 * @param attributes the additional image HTML attributes
	 * @param partialTag if <code>true</code>, the opening <code>&lt;img</code> and closing <code> /&gt;</code> is omitted
	 * @param req the current request
	 * 
	 * @return the created &lt;img src&gt; tag content
	 * 
	 * @throws CmsException in case something goes wrong
	 */
	public static String imageTagAction(String src, CmsImageScaler scaler, ServletRequest req) throws CmsException {

		CmsFlexController controller = CmsFlexController.getController(req);
		CmsObject cms = controller.getCmsObject();

		// resolve possible relative URI
		//src = CmsLinkManager.getAbsoluteUri(src, controller.getCurrentRequest().getElementUri());
		CmsUriSplitter splitSrc = new CmsUriSplitter(src);

		CmsResource imageRes = cms.readResource(splitSrc.getPrefix());
		CmsImageScaler reScaler = null;
		if (splitSrc.getQuery() != null) {
			// check if the original URI already has parameters, this is true if original has been cropped
			String[] scaleStr = CmsRequestUtil.createParameterMap(splitSrc.getQuery()).get(CmsImageScaler.PARAM_SCALE);
			if (scaleStr != null) {
				// use cropped image as a base for scaling
				reScaler = new CmsImageScaler(scaleStr[0]);
				scaler = reScaler.getCropScaler(scaler);
			}
		}

		// calculate target scale dimensions (if required)  
		if ((scaler.getHeight() <= 0) || (scaler.getWidth() <= 0)) {
			// read the image properties for the selected resource
			CmsImageScaler original = new CmsImageScaler(cms, imageRes);
			if (original.isValid()) {
				scaler = original.getReScaler(scaler);
			}
		}

		String imageLink = cms.getSitePath(imageRes);
		if (scaler.isValid()) {
			// now append the scaler parameters
			imageLink += scaler.toRequestParam();
		}
		return OpenCms.getLinkManager().substituteLink(cms, imageLink);

	}%>


<%
	try {
		CmsJspActionElement cms = new CmsJspActionElement(pageContext, request, response);
		CmsRequestContext reqContext = cms.getRequestContext();
		CmsObject cmsObj = cms.getCmsObject();

		String fileName = reqContext.getUri();
		CmsResource cfgFile = cmsObj.readResource(fileName);

		CmsFile file = cmsObj.readFile(cfgFile);
		Locale locale = null;
		CmsXmlContent content = CmsXmlContentFactory.unmarshal(cmsObj, file);
		String lang = request.getParameter("lang");
		if (!StringUtils.isBlank(lang) && content.hasLocale(new Locale(lang))) {
			locale = new Locale(lang);
		} else {
			locale = reqContext.getLocale();
		}

		Locale bestLocale = content.getBestMatchingLocale(locale);

		OpenCms.getSiteManager().getCurrentSite(new CmsJspActionElement(pageContext, request, response).getCmsObject()).getUrl();
		String menuId = request.getParameter("menuId");

		if (CmsStringUtil.isNotEmptyOrWhitespaceOnly(menuId)) {
			menuId = new String(menuId.getBytes("8859_1"), "UTF8");
			Map<String, Map<String, String>> mapping = new HashMap<String, Map<String, String>>();
			
			// patch OpenCms error (OpenCms return all nodes not selected)
			List<I_CmsXmlContentValue> vals = Collections.EMPTY_LIST;
			final String[] ALL_NODES = new String[] {"Tabs[1]/NewsTab", "Tabs[1]/EventTab", "Tabs[1]/UrlTab", "Tabs[1]/ContactTab"};
			for (String node : ALL_NODES) {
				List<I_CmsXmlContentValue> tmpVals = content.getValues(node, bestLocale);
				if (tmpVals.size() > vals.size()) {
					vals = tmpVals;
				}
			}
	

			String collectorName = null;
			String collectorParam = null;

			if (vals != null) {
				int i = 0;
				int newsTab = 0;
				int eventTab = 0;
				String collectorNameTag = null;
				String collectorParamTag = null;
				for (I_CmsXmlContentValue tab : vals) {
					String tabTag;
					if ("NewsTab".equals(tab.getName())) {
						newsTab++;
						tabTag = "NewsTab";
						i = newsTab;
						collectorNameTag = "NewsCollector";
						collectorParamTag = "NewsCollectorParam";
					} else if ("EventTab".equals(tab.getName())) {
						eventTab++;
						tabTag = "EventTab";
						i = eventTab;
						collectorNameTag = "EventCollector";
						collectorParamTag = "EventCollectorParam";
					} else {
						continue;
					}

					I_CmsXmlContentValue value = content.getValue("Tabs[1]/" + tabTag + "[" + i + "]/Title", bestLocale);

					if (menuId.equals(value.getStringValue(cmsObj))) {
						collectorName = content.getValue("Tabs[1]/" + tabTag + "[" + i + "]/" + collectorNameTag, bestLocale).getStringValue(cmsObj);
						collectorParam = content.getValue("Tabs[1]/" + tabTag + "[" + i + "]/" + collectorParamTag, bestLocale).getStringValue(cmsObj);

						if (content.hasValue("Tabs[1]/" + tabTag + "[" + i + "]/Mapping", bestLocale)) {
							List<I_CmsXmlContentValue> maps = content.getValues("Tabs[1]/" + tabTag + "[" + i + "]/Mapping", bestLocale);

							for (int j = 1; j <= maps.size(); j++) {
								Map<String, String> fieldMapping = new HashMap<String, String>();

								String field = getStringValue(content, "Tabs[1]/" + tabTag + "[" + i + "]/Mapping[" + j + "]/Field", bestLocale, cmsObj);
								String xmlNode = getStringValue(content, "Tabs[1]/" + tabTag + "[" + i + "]/Mapping[" + j + "]/XmlNode", bestLocale, cmsObj);

								String Default = getStringValue(content, "Tabs[1]/" + tabTag + "[" + i + "]/Mapping[" + j + "]/Default", bestLocale, cmsObj);
								String maxLength = getStringValue(content, "Tabs[1]/" + tabTag + "[" + i + "]/Mapping[" + j + "]/MaxLength", bestLocale, cmsObj);

								fieldMapping.put("xmlNode", xmlNode);
								if (Default != null) {
									fieldMapping.put("default", Default);
								}
								if (maxLength != null) {
									fieldMapping.put("maxLength", maxLength);
								}
								mapping.put(field, fieldMapping);
							}
						}
					}
				}
			}

			I_CmsResourceCollector collector = OpenCms.getResourceManager().getContentCollector(collectorName);

			List<CmsResource> resources = collector.getResults(cmsObj, collectorName, collectorParam);
			JSONObject objectMenu = new JSONObject();
			for (CmsResource resource : resources) {
				file = cmsObj.readFile(resource);
				content = CmsXmlContentFactory.unmarshal(cmsObj, file);

				if (!StringUtils.isBlank(lang) && content.hasLocale(new Locale(lang))) {
					locale = new Locale(lang);
				} else {
					locale = reqContext.getLocale();
				}

				bestLocale = content.getBestMatchingLocale(locale);
				Map<String, String> dataObject = new HashMap<String, String>();
				for (String key : mapping.keySet()) {

					Map<String, String> fieldMapping = mapping.get(key);
					String xmlNode = fieldMapping.get("xmlNode");
					String value = getStringValue(content, xmlNode, bestLocale, cmsObj);

					if (CmsStringUtil.isEmptyOrWhitespaceOnly(value)) {
						String def = fieldMapping.get("default");
						if (CmsStringUtil.isNotEmptyOrWhitespaceOnly(def)) {
							value = def;
						} else
							continue;
					}
					String maxLength = fieldMapping.get("maxLength");
					if (CmsStringUtil.isNotEmptyOrWhitespaceOnly(maxLength)) {
						int max = Integer.parseInt(maxLength);
						if (value.length() > max) {
							value = value.substring(0, max);
						}
					}
					

					//m_scaler.setHeight(400);
					//m_scaler.setWidth(400);
					//m_scaler.setType(2);
					//m_scaler.setRenderMode(1);

					if (key.equals("Image")) {
						value = imageTagAction(value, m_scaler, request);
					}

					dataObject.put(key, value);

					long lastModified = resource.getDateLastModified();

					dataObject.put("LastModified", "" + lastModified);
				}
				objectMenu.append("data", dataObject);
			}
			out.println(objectMenu);
		} else {

			long modifiedSince = request.getDateHeader(CmsRequestUtil.HEADER_IF_MODIFIED_SINCE);
			long lastModifiedTime = cfgFile.getDateLastModified();

			if (modifiedSince != -1 && modifiedSince > lastModifiedTime) {
				//response.sendError(HttpServletResponse.SC_NOT_MODIFIED);
				//return;
			}

			out.println(getJsonFromFile(cmsObj, bestLocale, reqContext.getLocale(), file));
		}
	} catch (Exception ex) {
		out.print("error");

		Writer writer = new StringWriter();
		PrintWriter printWriter = new PrintWriter(writer);
		ex.printStackTrace(printWriter);
		out.println(writer.toString());
	}
%>
