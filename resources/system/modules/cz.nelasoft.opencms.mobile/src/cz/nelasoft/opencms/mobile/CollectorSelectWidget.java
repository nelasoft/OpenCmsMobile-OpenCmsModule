package cz.nelasoft.opencms.mobile;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import org.opencms.file.CmsObject;
import org.opencms.file.collectors.I_CmsResourceCollector;
import org.opencms.main.OpenCms;
import org.opencms.widgets.CmsSelectWidget;
import org.opencms.widgets.CmsSelectWidgetOption;
import org.opencms.widgets.I_CmsWidget;
import org.opencms.widgets.I_CmsWidgetDialog;
import org.opencms.widgets.I_CmsWidgetParameter;

/**
 * Creates a select widget that contains either all available feed types, or all
 * configured collectors.
 * <p>
 * 
 */
public class CollectorSelectWidget extends CmsSelectWidget {

	/**
	 * Creates a new instance of the feed select widget.
	 * <p>
	 */
	public CollectorSelectWidget() {

		super();
	}

	/**
	 * Creates a new instance of the feed select widget.
	 * <p>
	 * 
	 * @param configuration
	 *            the widget configuration
	 */
	public CollectorSelectWidget(List configuration) {

		super(configuration);

	}

	/**
	 * Creates a new instance of the feed select widget.
	 * <p>
	 * 
	 * @param configuration
	 *            the widget configuration
	 */
	public CollectorSelectWidget(String configuration) {

		super(configuration);
	}

	/**
	 * @see org.opencms.widgets.CmsSelectWidget#newInstance()
	 */
	public I_CmsWidget newInstance() {

		return new CollectorSelectWidget(getConfiguration());
	}

	/**
	 * @see org.opencms.widgets.A_CmsSelectWidget#getSelectOptions()
	 */
	protected List<CmsSelectWidgetOption> getSelectOptions() {

		// for the test case this method needs to be in the feed package
		return super.getSelectOptions();
	}

	/**
	 * @see org.opencms.widgets.A_CmsSelectWidget#parseSelectOptions(org.opencms.file.CmsObject,
	 *      org.opencms.widgets.I_CmsWidgetDialog,
	 *      org.opencms.widgets.I_CmsWidgetParameter)
	 */
	protected List<CmsSelectWidgetOption> parseSelectOptions(CmsObject cms,
			I_CmsWidgetDialog widgetDialog, I_CmsWidgetParameter param) {

		if (getSelectOptions() == null) {
			String configuration = getConfiguration();
			if (configuration == null) {
				// workaround: use the default value to parse the options
				configuration = param.getDefault(cms);
			}

			List<CmsSelectWidgetOption> options = new ArrayList<CmsSelectWidgetOption>();

			// we want to get the list of configured resource collectors
			Iterator<I_CmsResourceCollector> i = OpenCms.getResourceManager()
					.getRegisteredContentCollectors().iterator();
			while (i.hasNext()) {
				// loop over all collectors and add all collector names
				I_CmsResourceCollector collector =  i.next();
				Iterator<String> j = collector.getCollectorNames().iterator();
				while (j.hasNext()) {
					String name = (String) j.next();
					// make "allInFolder" the default setting
					boolean isDefault = "allInFolder".equals(name);
					CmsSelectWidgetOption option = new CmsSelectWidgetOption(
							name, isDefault);
					options.add(option);
				}
			}

			setSelectOptions(options);
		}
		return getSelectOptions();
	}
}