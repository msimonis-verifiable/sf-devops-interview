public class fflib_Application {
    public class UnitOfWorkFactory {
        private List<SObjectType> sObjectTypes;
        public UnitOfWorkFactory(List<SObjectType> sObjectTypes) {
            this.sObjectTypes = sObjectTypes;
        }
    }

    public class ServiceFactory {
        private Map<Type, Type> servicesByType;
        public ServiceFactory(Map<Type, Type> servicesByType) {
            this.servicesByType = servicesByType;
        }
    }

    public class SelectorFactory {
        private Map<SObjectType, Type> selectorsByType;
        public SelectorFactory(Map<SObjectType, Type> selectorsByType) {
            this.selectorsByType = selectorsByType;
        }
    }
}
