//
//  SessionList.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/15/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI
import CoreData

class SessionListViewModel: ObservableObject {
    private var dataContext: NSManagedObjectContext?
    @Published var sessions: [Recording] = []

    init() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        dataContext = appDelegate.persistentContainer.viewContext
        self.sessions = []
        NotificationCenter.default.addObserver(self, selector: #selector(sessionsChanged), name: NSNotification.Name("sessionsChanged"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func fetchSessions() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Recording")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            let fetched: [NSManagedObject] = try dataContext?.fetch(request) ?? []
            sessions = fetched.map { session in
                return session as! Recording
            }

        } catch let error as NSError {
            print("Something went wrong. Error: \(error), \(error.userInfo)")
        }
    }

    @objc func sessionsChanged() {
        fetchSessions()
    }

}

struct SessionList: View {
    @ObservedObject var viewModel = SessionListViewModel()
    @State private var showingInfo = false
    @State private var showingProbe = false  // RoadCapture: camera probe (D-014)
    @State private var showingSmoke = false  // RoadCapture: "-multilens-smoke" records 8 s on launch
    private static var smokeRan = false

    var body: some View {
        ZStack {
        Color.black
        .ignoresSafeArea()
        NavigationView {
            VStack(alignment: .leading) {
                HStack {
                    Text("Recordings")
                        .foregroundColor(Color("TextColor"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding([.top, .leading], 15.0)
                    Spacer()
                    Button(action: {
                        showingProbe = true
                    }, label: {
                        Image(systemName: "camera.aperture")
                            .resizable()
                            .frame(width: 25, height: 25, alignment: .center)
                            .padding(.top, 17)
                            .padding(.trailing, 12)
                            .foregroundColor(Color("TextColor"))
                    }).sheet(isPresented: $showingProbe) {
                        ProbeView()
                    }
                    Button(action: {
                        showingInfo.toggle()
                    }, label: {
                        Image(systemName: "info.circle")
                            .resizable()
                            .frame(width: 25, height: 25, alignment: .center)
                            .padding(.top, 17)
                            .padding(.trailing, 20)
                            .foregroundColor(Color("TextColor"))
                    }).sheet(isPresented: $showingInfo) {
                        InformationView()
                    }
                }

                if !viewModel.sessions.isEmpty {
                    List {
                        ForEach(Array(viewModel.sessions.enumerated()), id: \.element) { i, recording in
                            NavigationLink(destination: SessionDetailView(recording: recording)) {
                                SessionRow(session: recording)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    Spacer()
                } else {
                    Spacer()
                    Text("No recorded sessions. Record one, and it will appear here.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 50.0)
                }
                // RoadCapture: two ways to record. ARKit = main lens + live poses (+ LiDAR);
                // Multi-lens = several lenses in sync, poses computed afterwards (D-014).
                HStack(spacing: 12) {
                    Spacer()
                    NavigationLink(destination: NewSessionView(), label: {
                        Text("Record (ARKit)")
                            .font(.headline)
                            .padding(.vertical, 18)
                            .padding(.horizontal, 16)
                            .background(Color("TextColor"))
                            .foregroundColor(Color("LightColor"))
                            .cornerRadius(30)
                    })
                    NavigationLink(destination: MultiLensRecordView(), label: {
                        Text("Multi-lens")
                            .font(.headline)
                            .padding(.vertical, 18)
                            .padding(.horizontal, 16)
                            .background(Color("TextColor"))
                            .foregroundColor(Color("LightColor"))
                            .cornerRadius(30)
                    })
                    Spacer()
                }
                .padding(.vertical, 20)
                .sheet(isPresented: $showingSmoke) {
                    NavigationView { MultiLensRecordView(autoRecordSeconds: 8) }
                }
                if (viewModel.sessions.isEmpty) {
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .background(Color("BackgroundColor").ignoresSafeArea())
            .onAppear {
                DispatchQueue.main.async {
                    viewModel.fetchSessions()
                }
                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).forEach({ url in
                    let relative = url.relativeString
                    print("relative url: \(relative)")
                })
                let delegate = UIApplication.shared.delegate as! AppDelegate
                delegate.appDaemon?.removeDeletedEntries()
                // Launched with "-probe" (e.g. from the Mac with devicectl): run the camera probe once.
                if ProcessInfo.processInfo.arguments.contains("-probe") && !CameraProbe.autoRan {
                    CameraProbe.autoRan = true
                    showingProbe = true
                }
                if ProcessInfo.processInfo.arguments.contains("-multilens-smoke") && !SessionList.smokeRan {
                    SessionList.smokeRan = true
                    showingSmoke = true
                }
        }
        }
        .background(Color("BackgroundColor").edgesIgnoringSafeArea(.all))
        }
    }
}

struct SessionList_Previews: PreviewProvider {
    static var previews: some View {
        SessionList()
    }
}
